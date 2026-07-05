#!/usr/bin/env python3
"""
Objective grader for a single eval run.

Usage:
    python3 grade_run.py <run_dir> [--no-exec] [--plugin-cache <dir>]

<run_dir> is e.g.
    terraform-test-generator-workspace/iteration-7/eval-1/with_skill/run-1

It must contain outputs/tests/ (generated suite) and a sibling
../eval_metadata.json (eval_id, module_dir, expectations).

Produces grading.json in <run_dir>/ with:
    expectations: [{text, passed, evidence}]
    summary: {passed, failed, total, pass_rate}
    timing: {} (filled by caller from the task notification)

Design: deterministic Python checks for every expectation, parsing the
module (.tf) for ground truth and the generated .tftest.hcl for evidence,
plus a `terraform test` execution check in an isolated module copy with a
shared provider plugin cache. No LLM judgment — objective and reusable.
"""
import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile
import textwrap
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent

# ---------------------------------------------------------------------------
# Module ground-truth parsing
# ---------------------------------------------------------------------------

def parse_module(module_dir: Path) -> dict:
    """Extract provider, data sources, required vars, validation vars from .tf files."""
    tf = ""
    for f in ("main.tf", "variables.tf", "outputs.tf"):
        p = module_dir / f
        if p.exists():
            tf += "\n" + p.read_text(errors="replace")

    # Provider: from required_providers source, else from resource prefixes
    provider = None
    m = re.search(r'source\s*=\s*"([^"]+)/([^"]+)"', tf)
    if m:
        provider = m.group(2)  # aws, azurerm, google, stackit
    if not provider:
        for pref in ("aws_", "azurerm_", "google_", "stackit_"):
            if re.search(rf'(resource|data)\s+"{pref}', tf):
                provider = pref.rstrip("_")
                break

    # Data sources: data "type" "name"
    data_sources = []
    for mm in re.finditer(r'data\s+"([a-zA-Z0-9_]+)"\s+"([a-zA-Z0-9_]+)"', tf):
        data_sources.append(f"{mm.group(1)}.{mm.group(2)}")

    # Variables: name + has default? + has validation block?
    required_vars = []
    validation_vars = []
    has_validation = False
    for vblock in re.finditer(
        r'variable\s+"([^"]+)"\s*\{(.*?)\n\}', tf, re.DOTALL
    ):
        vname = vblock.group(1)
        body = vblock.group(2)
        if not re.search(r'^\s*default\s*=', body, re.MULTILINE):
            required_vars.append(vname)
        if re.search(r'validation\s*\{', body):
            has_validation = True
            validation_vars.append(vname)

    return {
        "provider": provider,
        "data_sources": data_sources,
        "required_vars": required_vars,
        "validation_vars": validation_vars,
        "has_validation": has_validation,
        "tf_text": tf,
    }


# ---------------------------------------------------------------------------
# Generated-suite parsing
# ---------------------------------------------------------------------------

def find_tests_dir(outputs_dir: Path):
    """Locate the directory holding .tftest.hcl files under outputs/.

    Some generators write to outputs/tests/ directly; others nest an extra
    tests/ level (outputs/tests/tests/). Return the shallowest dir that
    actually contains .tftest.hcl files, preferring one named 'tests'.
    """
    if not outputs_dir.exists():
        return None
    candidates = {p.parent for p in outputs_dir.rglob("*.tftest.hcl")}
    if not candidates:
        return None
    return min(candidates, key=lambda d: (len(d.parts), d.name != "tests"))


def read_suite(tests_dir) -> dict:
    """Read all *.tftest.hcl + README.md + COVERAGE.md recursively under tests_dir.

    Generators use varied layouts (flat under tests/, nested tests/tests/,
    or tests/unit/ + tests/integration/ subdirs). Flatten by basename; on
    collision, qualify with the parent dir name.
    """
    files = {}
    if not tests_dir or not Path(tests_dir).exists():
        return files
    for p in sorted(Path(tests_dir).rglob("*")):
        if p.is_file() and (p.name.endswith(".tftest.hcl") or p.name.endswith(".md")):
            key = p.name
            if key in files:
                key = f"{p.parent.name}/{p.name}"
            files[key] = p.read_text(errors="replace")
    return files


def is_integration_file(fname: str, content: str) -> bool:
    """Classify a test file as integration (real-provider apply) by name OR content.

    Content rule: has an explicit `command = apply` run and no mocking machinery
    (mock_provider / override_*) — i.e. it would hit a real provider. This keeps
    the grader fair to generators that don't use the integration_* naming.
    """
    name = Path(fname).name
    if name.startswith("integration_") or Path(fname).parent.name == "integration":
        return True
    if re.search(r'command\s*=\s*apply', content) \
            and "mock_provider" not in content \
            and not re.search(r'override_(data|module|resource)', content):
        return True
    return False


def parse_run_blocks(hcl: str) -> list:
    """Return list of run blocks: {name, command, providers, conditions, has_expect_failures}.

    conditions = list of (raw_condition_line, is_multiline) for assert blocks in that run.
    """
    runs = []
    lines = hcl.splitlines()
    i = 0
    n = len(lines)
    while i < n:
        line = lines[i]
        m = re.match(r'\s*run\s+"([^"]+)"\s*\{', line)
        if not m:
            i += 1
            continue
        # walk the block respecting brace depth
        depth = line.count("{") - line.count("}")
        start = i
        block_lines = [line]
        j = i + 1
        while j < n and depth > 0:
            block_lines.append(lines[j])
            depth += lines[j].count("{") - lines[j].count("}")
            j += 1
        block = "\n".join(block_lines)
        run = {
            "name": m.group(1),
            "command": None,
            "providers": None,
            "conditions": [],
            "has_expect_failures": "expect_failures" in block,
            "variables_text": block,
        }
        cm = re.search(r'command\s*=\s*(plan|apply)', block)
        if cm:
            run["command"] = cm.group(1)
        pm = re.search(r'providers\s*=\s*\{([^}]*)\}', block, re.DOTALL)
        if pm:
            run["providers"] = pm.group(1).strip()
        # assert conditions: grab each `condition = <expr>` within assert{} that lives in this run
        for am in re.finditer(r'assert\s*\{([^{}]*(?:\{[^{}]*\}[^{}]*)*)\}', block, re.DOTALL):
            assert_body = am.group(1)
            cm2 = re.search(r'condition\s*=\s*(.*)', assert_body, re.DOTALL)
            if cm2:
                cond = cm2.group(1).strip()
                # condition ends at the line containing error_message or closing brace
                cond_one_line = cond.split("error_message")[0].rstrip().rstrip("}")
                multiline = "\n" in cond_one_line.strip() and not cond_one_line.strip().endswith("true") and len(cond_one_line.splitlines()) > 1
                # Better multiline test: does the condition expression span >1 line before error_message?
                expr_lines = [l for l in cond_one_line.splitlines() if l.strip()]
                is_multiline = len(expr_lines) > 1
                run["conditions"].append((cond_one_line.strip(), is_multiline))
        runs.append(run)
        i = j
    return runs


def all_runs(suite: dict) -> list:
    out = []
    for fname, content in suite.items():
        if fname.endswith(".tftest.hcl"):
            for r in parse_run_blocks(content):
                r["_file"] = fname
                out.append(r)
    return runs_with_file(out)


def runs_with_file(runs):
    return runs


# ---------------------------------------------------------------------------
# Individual checks: each returns (passed: bool, evidence: str)
# ---------------------------------------------------------------------------

def check_data_source_mocked(expectation, ctx):
    """data.X mocked via ANY working mechanism: override_data target, or
    mock_data "<type>" inside mock_provider. Mechanism choice is not graded."""
    ds = ctx["ds_mentioned"]  # e.g. 'aws_availability_zones.available'
    if not ds:
        return False, "No data source name found in expectation text."
    ds_type = ds.split(".")[0]
    unit_mock = ctx["unit_mock_text"]
    override_blocks = re.findall(r'override_data\s*\{(.*?)\n\s*\}', unit_mock, re.DOTALL)
    if any(re.search(rf'target\s*=\s*data\.{re.escape(ds)}', b) for b in override_blocks):
        return True, f"override_data block with target = data.{ds} found in unit/mock tests."
    if re.search(rf'mock_data\s+"{re.escape(ds_type)}"\s*\{{', unit_mock):
        return True, f'mock_data "{ds_type}" inside mock_provider mocks data.{ds} (file-level).'
    if override_blocks and ds in unit_mock:
        return True, f"override_data used and data.{ds} referenced in unit/mock tests."
    return False, f"data.{ds} is not mocked (no override_data target, no mock_data \"{ds_type}\")."


def check_unit_providers_binding(expectation, ctx):
    """Legacy: every run in unit_*.tftest.hcl includes providers = { <prov> = <prov>.mock }."""
    prov = ctx["provider"]
    unit_runs = [r for r in ctx["runs"] if r["_file"].startswith("unit_") and r["command"]]
    if not unit_runs:
        return False, "No run blocks found in unit_*.tftest.hcl files."
    missing = [f"{r['_file']}::{r['name']}" for r in unit_runs
               if not (r["providers"] and f"{prov}." in r["providers"] and "mock" in r["providers"])]
    if missing:
        return False, f"Runs missing providers={{{prov}={prov}.mock}}: {', '.join(missing[:5])}"
    return True, f"All {len(unit_runs)} unit runs bind providers = {{{prov} = {prov}.mock}}."


def check_unit_mock_provider(expectation, ctx):
    """Functional: non-integration tests run against a mocked provider.

    Accepts either form:
    - unaliased mock_provider "<prov>" {} — replaces the default provider, no
      per-run binding needed;
    - aliased mock_provider — then every plan/apply run in that file must bind
      it via providers = { <prov> = <prov>.<alias> }.
    """
    prov = ctx["provider"]
    nonint_files = {f: c for f, c in ctx["suite"].items()
                    if f.endswith(".tftest.hcl") and not is_integration_file(f, c)}
    if not nonint_files:
        return False, "No non-integration test files generated."
    problems = []
    any_mock = False
    for fname, content in nonint_files.items():
        mocks = []  # (provider, alias_or_None) — brace-walk each block for its alias
        for m in re.finditer(r'mock_provider\s+"(\w+)"\s*\{', content):
            depth, j = 1, m.end()
            while j < len(content) and depth > 0:
                depth += {"{": 1, "}": -1}.get(content[j], 0)
                j += 1
            am = re.search(r'alias\s*=\s*"(\w+)"', content[m.end():j])
            mocks.append((m.group(1), am.group(1) if am else None))
        if not mocks:
            continue  # e.g. validation-only file; execution check covers real gaps
        any_mock = True
        if any(alias is None for _, alias in mocks):
            continue  # unaliased mock replaces the default provider for the file
        alias_names = {alias for _, alias in mocks}
        for r in parse_run_blocks(content):
            if not r["command"]:
                continue
            bound = r["providers"] and any(f"{prov}.{al}" in r["providers"] for al in alias_names)
            if not bound:
                problems.append(f"{fname}::{r['name']}: aliased mock not bound")
    if not any_mock:
        return False, "No mock_provider defined in any non-integration test file."
    if problems:
        return False, f"Aliased mock defined but not bound in runs: {'; '.join(problems[:5])}"
    return True, f"Non-integration tests run against a mocked {prov} provider (aliased mocks bound or default mock in place)."


def check_no_plan_computed(expectation, ctx):
    """No assertion under command=plan references a computed attribute."""
    # Extract the attr list from the expectation, e.g. (.id, .arn, .self_link)
    attrs = re.findall(r'\.([a-zA-Z_]+)', expectation)
    # Filter to plausible computed attrs mentioned
    # NOTE: "name" is deliberately absent — on most resources (azurerm_resource_group,
    # storage accounts, buckets) .name is an argument set from config, not computed;
    # flagging it produced false positives on suites that pass execution.
    computed = set(a for a in attrs if a in {
        "id", "arn", "self_link", "number", "endpoint",
        "connection_string", "etag", "uid", "primary_access_key"
    })
    if not computed:
        computed = {"id", "arn", "self_link"}
    plan_runs = [r for r in ctx["runs"] if r["command"] == "plan"]
    offenders = []
    for r in plan_runs:
        for cond, _ in r["conditions"]:
            for a in computed:
                if re.search(rf'\.{a}\b', cond):
                    offenders.append(f"{r['_file']}::{r['name']} references .{a}")
    # Also scan whole plan blocks (catches conditions our parser missed)
    for fname, content in ctx["suite"].items():
        if not fname.endswith(".tftest.hcl"):
            continue
        # crude: split by run blocks is already done; do a secondary full-text scan inside plan sections
        for blk in re.finditer(r'run\s+"[^"]+"\s*\{(.*?)\n\}', content, re.DOTALL):
            if re.search(r'command\s*=\s*plan', blk.group(1)):
                for a in computed:
                    # only count inside assert conditions
                    for asm in re.finditer(r'condition\s*=\s*([^\n]*(?:\n(?!\s*(error_message|providers|variables|module|command|assert|run|\})))*)', blk.group(1)):
                        if re.search(rf'\.{a}\b', asm.group(1)):
                            offenders.append(f"{fname} plan-run condition references .{a}")
    offenders = list(dict.fromkeys(offenders))
    if offenders:
        return False, f"Computed attrs under plan: {'; '.join(offenders[:5])}"
    return True, f"No computed attributes ({'/'.join(sorted(computed))}) asserted under command = plan."


def check_no_set_index(expectation, ctx):
    text = ctx["all_text"]
    hits = re.findall(r'\.(ingress|egress)\[0\]', text)
    if hits:
        return False, f"Found [0] indexing on set-type attrs: {hits[:5]}"
    return True, "No [0] indexing on ingress/egress set-type attributes."


def check_single_line_asserts(expectation, ctx):
    multiline = []
    for r in ctx["runs"]:
        for cond, is_ml in r["conditions"]:
            if is_ml:
                multiline.append(f"{r['_file']}::{r['name']}")
    if multiline:
        return False, f"Multi-line assert conditions in: {', '.join(list(dict.fromkeys(multiline))[:5])}"
    return True, "All assert conditions are single-line."


def check_naming_testsafe(expectation, ctx):
    text = ctx["all_text"]
    env_ok = re.search(r'environment\s*=\s*"test"', text) or re.search(r'environment\s*=\s*"tftest', text)
    prefix_ok = "test-" in text or "tftest" in text
    if env_ok and prefix_ok:
        return True, "Naming transformed (environment=test/tftest, test- prefix present)."
    if env_ok or prefix_ok:
        return True, "Partial test-safe naming applied."
    return False, "No test-safe naming transforms found (environment=test / test- prefix)."


def check_required_vars_set(expectation, ctx):
    required = ctx["module"]["required_vars"]
    if not required:
        return True, "Module has no required variables without defaults."
    runs_all = [r for r in ctx["runs"] if r["command"]]  # runs that instantiate the module
    # A run instantiates the module if it has a module{} block or sets variables
    mod_runs = [r for r in runs_all if "module " in r["variables_text"] or "variables" in r["variables_text"]]
    if not mod_runs:
        mod_runs = runs_all
    if not mod_runs:
        return False, "No run blocks found."
    missing = []
    for r in mod_runs:
        for v in required:
            # present if `v =` or `v =` appears in the run's variables/module block
            if not re.search(rf'\b{re.escape(v)}\s*=', r["variables_text"]):
                missing.append(f"{r['_file']}::{r['name']} missing var '{v}'")
    if missing:
        return False, f"Required vars not set: {'; '.join(missing[:5])}"
    return True, f"All required vars ({', '.join(required)}) set in every run block."


def check_validation_expect_failures(expectation, ctx):
    # Filename-agnostic: expect_failures may live in validation_* OR unit_validation etc.
    nonint = ctx["nonint_text"]
    if not nonint.strip():
        return False, "No non-integration test files generated."
    if "expect_failures" not in nonint:
        return False, "No expect_failures used in any test file."
    ef_count = len(re.findall(r'expect_failures', nonint))
    return True, f"Tests use expect_failures for invalid inputs ({ef_count} occurrences)."


def check_validation_coverage(expectation, ctx):
    """Validation tests cover all variables that declare validation blocks."""
    val_vars = ctx["module"]["validation_vars"]
    if not val_vars:
        return True, "Module declares no validation blocks (nothing to cover)."
    nonint = ctx["nonint_text"]
    if not nonint.strip():
        return False, f"No non-integration test files; expected coverage of: {', '.join(val_vars)}"
    covered = []
    for v in val_vars:
        if re.search(rf'\b{re.escape(v)}\s*=\s*', nonint):
            covered.append(v)
    ef_count = len(re.findall(r'expect_failures', nonint))
    if len(covered) >= len(val_vars) or ef_count >= len(val_vars):
        return True, f"Validation tests cover {', '.join(covered or val_vars)} ({ef_count} expect_failures)."
    return False, f"Validation coverage incomplete: covered {covered} of {val_vars} ({ef_count} expect_failures)."


def check_compliance_nontrivial(expectation, ctx):
    comp_text = ctx["compliance_text"]
    if not comp_text.strip():
        return False, "No compliance_*.tftest.hcl generated."
    if re.search(r'condition\s*=\s*true\b', comp_text):
        return False, "Compliance tests contain trivial `condition = true`."
    topics = []
    low = comp_text.lower()
    if any(k in low for k in ("encrypt", "kms", "tls", "ssl", "min_tls", "cmek", "default_kms")):
        topics.append("encryption")
    if any(k in low for k in ("tag", "label", "labels")):
        topics.append("tagging")
    if any(k in low for k in ("cidr", "ingress", "egress", "0.0.0.0/0", "network", "uniform_bucket", "allusers", "allauthenticated", "iam")):
        topics.append("network")
    if any(k in low for k in ("backup", "retention")):
        topics.append("backup")
    if any(k in low for k in ("version",)):
        topics.append("version")
    # eval-1 explicitly wants "at least two of: encryption, tagging, network security";
    # eval-2/3/5 name specific topics joined by "and/or" — one is enough.
    threshold = 2 if "at least two" in expectation.lower() else 1
    topics = list(dict.fromkeys(topics))
    if len(topics) >= threshold:
        return True, f"Non-trivial compliance conditions covering: {', '.join(topics)} (threshold {threshold})."
    return False, f"Compliance conditions too narrow; topics found: {topics or 'none'} (need {threshold})."


def check_compliance_topic(expectation, ctx):
    """Expectation names specific compliance topics (TLS/CMEK/uniform_bucket/allUsers/backup/labels)."""
    comp_text = ctx["compliance_text"]
    low = comp_text.lower()
    wanted = []
    if "tls" in expectation.lower():
        wanted.append(("min_tls_version", "min_tls_version" in low or "tls1_2" in low or "tls" in low))
    if "cmek" in expectation.lower() or "default_kms" in expectation.lower():
        wanted.append(("cmek/kms", "default_kms_key_name" in low or "cmek" in low or "kms" in low))
    if "uniform_bucket" in expectation.lower():
        wanted.append(("uniform_bucket_level_access", "uniform_bucket_level_access" in low))
    if "allusers" in expectation.lower() or "allauthenticated" in expectation.lower():
        has_bad = ("allusers" in low or "allauthenticatedusers" in low)
        # The check is that compliance VERIFIES absence — look for a condition asserting member != allUsers
        verified = bool(re.search(r'(allUsers|allAuthenticatedUsers)', comp_text))
        wanted.append(("no-allUsers check", verified))
    if "backup" in expectation.lower() or "retention" in expectation.lower():
        wanted.append(("backup/retention", "backup" in low or "retention" in low))
    if "version pinning" in expectation.lower() or "postgres_version" in expectation.lower():
        wanted.append(("version pinning", "version" in low))
    if "labels" in expectation.lower() and "tags" in expectation.lower():
        # asserts on .labels not .tags
        wanted.append(("labels-not-tags", ".labels" in comp_text))
    if "encryption" in expectation.lower() and "storage" in expectation.lower():
        wanted.append(("storage encryption", "enable_https_traffic_only" in low or "min_tls" in low or "encryption" in low))
    if not wanted:
        # generic: at least one of the expected topics present
        return (len(low) > 0, "compliance file present") if comp_text.strip() else (False, "no compliance file")
    failed = [name for name, ok in wanted if not ok]
    if failed:
        return False, f"Compliance missing topic(s): {', '.join(failed)}."
    return True, f"Compliance covers: {', '.join(n for n,_ in wanted)}."


def check_integration_apply(expectation, ctx):
    int_text = ctx["integration_text"]
    if not int_text.strip():
        return False, "No integration_*.tftest.hcl generated."
    if "command = apply" not in int_text and "command=apply" not in int_text:
        return False, "Integration tests do not use command = apply."
    return True, "Integration tests include at least one command = apply run block."


def check_naming_pattern(expectation, ctx):
    names = [f for f in ctx["suite"] if f.endswith(".tftest.hcl")]
    if not names:
        return False, "No .tftest.hcl files generated."
    prefixes = ("unit_", "integration_", "mock_", "validation_", "compliance_", "advanced_", "multi_provider_")
    bad = [n for n in names if not n.startswith(prefixes)]
    if bad:
        return False, f"Non-conforming test file names: {bad}"
    return True, f"{len(names)} test files follow the naming pattern ({', '.join(sorted(set(n.split('_')[0]+'_' for n in names)))})."


NEGATION_MARKERS = ("never", "not ", "don't", "do not", "❌", "wrong", "no such",
                    "doesn't", "isn't", "avoid", "there is no", "instead of")


def _is_negated_line(line):
    low = line.lower()
    return any(m in low for m in NEGATION_MARKERS)


def check_readme_filter(expectation, ctx):
    """Conditional: IF docs show file-selecting test commands, they must use -filter=.

    Vacuously true when no file-selecting commands are documented (docs are not a
    required deliverable). Lines that quote the wrong form to warn against it
    (\"Never pass ...\") are not counted as violations.
    """
    docs = "\n".join(v for k, v in ctx["suite"].items() if k.endswith(".md"))
    if not docs.strip():
        return True, "No docs generated — no file-selecting commands to check (vacuous pass)."
    positional = []
    for line in docs.splitlines():
        if _is_negated_line(line):
            continue
        for m in re.finditer(r'(?:terraform|tofu)\s+test\s+([^-\s`][^\s`]*\.tftest\.hcl)', line):
            positional.append(m.group(1))
    uses_filter = "-filter=" in docs
    if positional:
        return False, f"Docs pass test files as positional args (silently ignored): {positional[:3]}"
    if not uses_filter:
        return True, "Docs document no file-selecting commands (vacuous pass)."
    return True, "Docs select files via -filter= and use no positional file args."


def check_readme_tofu(expectation, ctx):
    rd = ctx["suite"].get("README.md", "")
    has_tf = "terraform test" in rd.lower()
    has_tofu = "tofu test" in rd.lower()
    if has_tf and has_tofu:
        return True, "README documents both terraform test and tofu test."
    return False, f"README missing command parity (terraform: {has_tf}, tofu: {has_tofu})."


def check_readme_testsdir_cost(expectation, ctx):
    rd = ctx["suite"].get("README.md", "")
    low = rd.lower()
    testsdir = "tests/" in low or "tests directory" in low or "tests folder" in low
    cost = any(k in low for k in ("cost", "real resource", "billing", "real cloud", "real infrastructure", "warning"))
    miss = []
    if not testsdir: miss.append("tests/ directory mention")
    if not cost: miss.append("cost/safety warning")
    if miss:
        return False, f"README missing: {', '.join(miss)}."
    return True, "README mentions tests/ directory and includes cost/safety warnings."


def check_coverage_table(expectation, ctx):
    cov = ctx["suite"].get("COVERAGE.md", "")
    if not cov.strip():
        return False, "No COVERAGE.md generated."
    # markdown table: a line with | ... | and a separator |---|
    has_table = bool(re.search(r'^\|.+\|$', cov, re.MULTILINE)) and bool(re.search(r'^\|[\s:|-]+\|$', cov, re.MULTILINE))
    if has_table:
        return True, "COVERAGE.md contains a markdown summary table."
    return False, "COVERAGE.md has no markdown table."


def check_readme_version(expectation, ctx):
    rd = ctx["suite"].get("README.md", "")
    if "1.7.0" in rd:
        return True, "README states Terraform/OpenTofu >= 1.7.0."
    return False, "README does not state the 1.7.0 minimum (mock providers)."


def check_no_plan_resource_changes_cleanup(expectation, ctx):
    text = ctx["all_text"]
    hits = []
    if "plan.resource_changes" in text:
        hits.append("plan.resource_changes")
    # Only flag -cleanup when emitted as an actual command flag. Prose that
    # correctly documents the flag's NON-existence ("There is no -cleanup flag")
    # must not count — that's the right thing to write.
    for line in text.splitlines():
        if re.search(r'(terraform|tofu)\s+test\b[^\n]*-cleanup', line) and not _is_negated_line(line):
            hits.append(f"-cleanup emitted as command flag: {line.strip()[:80]}")
            break
    if hits:
        return False, f"Forbidden references present: {hits}."
    return True, "No plan.resource_changes refs and no -cleanup emitted as a command flag."


def check_no_validation_tests(expectation, ctx):
    """Eval-3 negative: module has no validation blocks — no expect_failures anywhere."""
    hits = [f for f, c in ctx["suite"].items()
            if f.endswith(".tftest.hcl") and "expect_failures" in c]
    if hits:
        return False, f"expect_failures present despite no validation blocks: {hits[:3]}"
    return True, "No expect_failures runs generated (module has nothing to validate)."


def check_no_data_mocks(expectation, ctx):
    """Eval-3 negative: module has no data sources — no override_data / mock_data."""
    hits = []
    for f, c in ctx["suite"].items():
        if f.endswith(".tftest.hcl") and re.search(r'\b(override_data|mock_data)\b', c):
            hits.append(f)
    if hits:
        return False, f"Data-source mocking present despite no data sources: {hits[:3]}"
    return True, "No override_data or mock_data blocks (module has no data sources)."


def check_provider_detected(expectation, ctx):
    prov = ctx["provider"]
    if not prov:
        return False, "Could not detect provider from module."
    # Scan only .tftest.hcl content — docs prose may legitimately mention other
    # clouds ("unlike AWS ...") without any provider leaking into the tests.
    tf_text = "\n".join(v for k, v in ctx["suite"].items() if k.endswith(".tftest.hcl"))
    wrong = {"aws", "azurerm", "google", "stackit"} - {prov}
    leaked = [w for w in wrong if re.search(rf'\b{w}\b', tf_text)]
    right_present = prov in tf_text.lower()
    if leaked:
        return False, f"Wrong provider(s) leaked into test files: {leaked}."
    if not right_present:
        return False, f"Provider {prov} not configured in test files."
    return True, f"Provider correctly detected as {prov}; no other providers leaked."


def check_uuid_format(expectation, ctx):
    text = ctx["all_text"]
    uuids = re.findall(r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}', text)
    if uuids:
        return True, f"Valid UUID-format mock values found ({len(uuids)})."
    return False, "No valid 8-4-4-4-12 UUID-format values in mocks."


def check_project_id_every_run(expectation, ctx):
    required = ctx["module"]["required_vars"]
    if "project_id" not in required and "project_id" not in ctx["module"]["tf_text"]:
        return True, "Module has no project_id variable."
    runs_all = [r for r in ctx["runs"] if r["command"]]
    missing = [f"{r['_file']}::{r['name']}" for r in runs_all
               if not re.search(r'\bproject_id\s*=', r["variables_text"])]
    if missing:
        return False, f"Runs missing project_id: {'; '.join(missing[:5])}"
    return True, "project_id set in every run block."


def check_labels_not_tags(expectation, ctx):
    comp = ctx["compliance_text"]
    if not comp.strip():
        return False, "No compliance tests generated."
    if ".labels" in comp and ".tags" not in comp:
        return True, "Compliance asserts on .labels (not .tags)."
    if ".labels" in comp:
        return True, "Compliance asserts on .labels."
    return False, "Compliance does not assert on .labels."


def check_execution(expectation, ctx, exec_result):
    return exec_result


# ---------------------------------------------------------------------------
# Dispatch: expectation text -> check function
# ---------------------------------------------------------------------------

def build_context(run_dir: Path, eval_meta: dict) -> dict:
    # Scan root: recurse into all subdir layouts (outputs/tests/, outputs/tests/tests/,
    # outputs/tests/unit/, etc.) from the outputs/ directory itself.
    tests_dir = run_dir / "outputs"
    module_dir = REPO / eval_meta["module_dir"]
    module = parse_module(module_dir)
    suite = read_suite(tests_dir)
    all_text = "\n".join(suite.values())
    runs = all_runs(suite)

    # Category texts: prefer the naming convention when present, but FALL BACK to
    # content-based classification so a suite with different file names is graded
    # on its content, not its naming. Without the fallback, one naming deviation
    # cascaded into unit/compliance/integration failures.
    tf_files = {k: v for k, v in suite.items() if k.endswith(".tftest.hcl")}
    int_files = {k: v for k, v in tf_files.items() if is_integration_file(k, v)}
    nonint_files = {k: v for k, v in tf_files.items() if k not in int_files}
    nonint_text = "\n".join(nonint_files.values())

    def named(prefixes, dirnames):
        return "\n".join(v for k, v in suite.items()
                         if Path(k).name.startswith(prefixes) or Path(k).parent.name in dirnames)

    unit_mock_text = named(("unit_", "mock_"), ("unit", "mock")) or nonint_text
    compliance_text = named(("compliance_",), ("compliance",)) or nonint_text
    integration_text = named(("integration_",), ("integration",)) or "\n".join(int_files.values())

    return {
        "run_dir": run_dir,
        "eval_meta": eval_meta,
        "module": module,
        "provider": module["provider"],
        "suite": suite,
        "tests_dir": tests_dir,
        "all_text": all_text,
        "runs": runs,
        "unit_mock_text": unit_mock_text,
        "validation_text": named(("validation_",), ("validation",)) or nonint_text,
        "compliance_text": compliance_text,
        "integration_text": integration_text,
        "nonint_text": nonint_text,
    }


def first_data_source(expectation):
    m = re.search(r'data\.([a-zA-Z0-9_]+\.[a-zA-Z0-9_]+)', expectation)
    return m.group(1) if m else None


def grade_expectation(expectation, ctx, exec_result):
    text = expectation
    low = text.lower()

    def run(check, *args):
        try:
            return check(text, *args, ctx) if args else (lambda: check(text, ctx))() \
                if check.__code__.co_argcount == 2 else check(text, ctx)
        except Exception as e:
            return False, f"check error: {e}"

    # Order matters: most specific first. Negative expectations (eval-3) must
    # precede the mocking branches — their text also mentions override_data.
    if "execution check" in low or "pass terraform test" in low or "execute green" in low or "execute" in low and "terraform test" in low:
        return exec_result
    if "no validation tests are generated" in low:
        return check_no_validation_tests(text, ctx)
    if "no data-source mocking is generated" in low:
        return check_no_data_mocks(text, ctx)
    if "override_data" in low or "any working mechanism" in low:
        ctx["ds_mentioned"] = first_data_source(text)
        return check_data_source_mocked(text, ctx)
    if "execute against a mocked provider" in low:
        return check_unit_mock_provider(text, ctx)
    if low.startswith("provider is detected") or "no aws or" in low or "no aws/azurerm" in low or "no aws/azurerm/google" in low or "providers leak" in low:
        return check_provider_detected(text, ctx)
    if "providers =" in low and ".mock" in low:
        return check_unit_providers_binding(text, ctx)
    if "computed attribute" in low or "command = plan references" in low or ("command = plan" in low and "computed" in low):
        return check_no_plan_computed(text, ctx)
    if "[0]" in low and "set-type" in low:
        return check_no_set_index(text, ctx)
    if "single line" in low or "single-line" in low:
        return check_single_line_asserts(text, ctx)
    if "naming variables" in low or "test-safe" in low or "test- prefix" in low:
        return check_naming_testsafe(text, ctx)
    if "is set in every run block" in low or "required module variables" in low or "required variables" in low:
        # covers: "All required module variables ... set in every run block",
        # "bucket_name ... is set in every run block", "project_id ... every run block"
        return check_required_vars_set(text, ctx)
    if "expect_failures targeted" in low:
        return check_validation_expect_failures(text, ctx)
    if ("validation tests cover" in low) or ("validation tests are generated" in low) or ("validation tests" in low and ("all" in low or "variables that declare" in low or "every" in low)):
        return check_validation_coverage(text, ctx)
    if "no validation_" in low and "files are generated" in low:
        # eval-3 negative expectation
        has = any(k.startswith("validation_") for k in ctx["suite"])
        return (not has, "No validation_*.tftest.hcl files present." if not has else "validation files were generated (should not be).")
    if "no mock_" in low and "files are generated" in low:
        has = any(k.startswith("mock_") for k in ctx["suite"])
        return (not has, "No mock_*.tftest.hcl files present." if not has else "mock files were generated (should not be).")
    if "at most" in low and "tftest.hcl files total" in low:
        n = len([k for k in ctx["suite"] if k.endswith(".tftest.hcl")])
        # extract the cap
        m = re.search(r'at most (\d+)', low)
        cap = int(m.group(1)) if m else 4
        return (n <= cap, f"{n} .tftest.hcl files (cap {cap}).")
    if "compliance tests contain non-trivial" in low:
        return check_compliance_nontrivial(text, ctx)
    if low.startswith("compliance tests") or "compliance tests assert" in low or "compliance tests check" in low or "compliance tests verify" in low or "compliance tests cover" in low:
        return check_compliance_topic(text, ctx)
    if "integration test files contain" in low or ("integration" in low and "command = apply" in low):
        return check_integration_apply(text, ctx)
    if "naming pattern" in low or "documented naming pattern" in low:
        return check_naming_pattern(text, ctx)
    if "-filter" in low and "positional" in low:
        return check_readme_filter(text, ctx)
    if "tofu test" in low and ("equivalent" in low or "documents both" in low or "terraform test and" in low):
        return check_readme_tofu(text, ctx)
    if "tests/" in low and "directory" in low and ("cost" in low or "safety" in low or "warning" in low):
        return check_readme_testsdir_cost(text, ctx)
    if "coverage.md" in low and ("summary table" in low or "per-test-type" in low):
        return check_coverage_table(text, ctx)
    if "1.7.0" in low:
        return check_readme_version(text, ctx)
    if "plan.resource_changes" in low or "-cleanup" in low:
        return check_no_plan_resource_changes_cleanup(text, ctx)
    if "uuid" in low:
        return check_uuid_format(text, ctx)
    if "project_id is set in the variables block" in low or "project_id" in low and "every run block" in low:
        return check_project_id_every_run(text, ctx)
    if "labels" in low and "tags" in low:
        return check_labels_not_tags(text, ctx)
    # Fallback: unverified
    return False, "No automated check mapped for this expectation."


# ---------------------------------------------------------------------------
# Execution check (terraform test) in an isolated module copy
# ---------------------------------------------------------------------------

def execution_check(ctx, plugin_cache: Path, timeout=180) -> tuple:
    src = ctx["tests_dir"]  # run_dir / "outputs" (the recursive scan root)
    module_dir = REPO / ctx["eval_meta"]["module_dir"]
    # Gather all .tftest.hcl recursively; classify as integration vs non-integration
    all_tf = list(src.rglob("*.tftest.hcl")) if src.exists() else []
    # Content-aware: a real-provider apply file must not run here regardless of
    # its name; a mocked-apply unit file is safe to run regardless of its name.
    non_int = [p for p in all_tf
               if not is_integration_file(str(p.relative_to(src)), p.read_text(errors="replace"))]
    if not non_int:
        return False, "No non-integration test files to execute."
    if shutil.which("terraform") is None:
        return False, "terraform not on PATH; execution skipped (counted as fail)."
    tmp = Path(tempfile.mkdtemp(prefix=f"grade-eval{ctx['eval_meta']['eval_id']}-"))
    try:
        # copy module .tf files
        for f in ("main.tf", "variables.tf", "outputs.tf"):
            modf = module_dir / f
            if modf.exists():
                shutil.copy2(modf, tmp / f)
        for tf in module_dir.glob("*.tf"):
            if tf.name not in ("main.tf", "variables.tf", "outputs.tf") and tf.exists():
                shutil.copy2(tf, tmp / tf.name)
        # Flatten ALL generated test files into tmp/tests/ (basename); skip collisions
        dst_tests = tmp / "tests"
        dst_tests.mkdir(exist_ok=True)
        seen = set()
        for p in all_tf:
            if p.name not in seen:
                shutil.copy2(p, dst_tests / p.name)
                seen.add(p.name)
        env = os.environ.copy()
        env["TF_PLUGIN_CACHE_DIR"] = str(plugin_cache)
        env["TF_INPUT"] = "0"
        # init
        init = subprocess.run(
            ["terraform", "init", "-backend=false", "-input=false"],
            cwd=tmp, env=env, capture_output=True, text=True, timeout=timeout
        )
        if init.returncode != 0:
            tail = "\n".join((init.stderr + init.stdout).splitlines()[-8:])
            return False, f"terraform init failed:\n{tail}"
        non_int_names = {p.name for p in non_int}
        filters = ["-filter=tests/" + name for name in sorted(non_int_names)]
        test = subprocess.run(
            ["terraform", "test"] + filters,
            cwd=tmp, env=env, capture_output=True, text=True, timeout=timeout
        )
        out = test.stdout + "\n" + test.stderr
        summary = re.findall(r'(\d+) passed, (\d+) failed', out)
        if test.returncode == 0:
            s = summary[-1] if summary else ("?", "0")
            return True, f"terraform test green ({s[0]} passed, {s[1]} failed)."
        tail = "\n".join(out.splitlines()[-12:])
        return False, f"terraform test failed:\n{tail}"
    except subprocess.TimeoutExpired:
        return False, f"terraform test timed out (>{timeout}s)."
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("run_dir")
    ap.add_argument("--no-exec", action="store_true", help="skip terraform execution check")
    ap.add_argument("--plugin-cache",
                    default=str(Path.home() / ".terraform.d" / "plugin-cache"))
    ap.add_argument("--json-out", default=None)
    args = ap.parse_args()

    run_dir = Path(args.run_dir)
    eval_dir = run_dir.parent.parent  # eval-N
    meta_path = eval_dir / "eval_metadata.json"
    import json
    eval_meta = json.loads(meta_path.read_text())

    ctx = build_context(run_dir, eval_meta)

    plugin_cache = Path(args.plugin_cache)
    plugin_cache.mkdir(parents=True, exist_ok=True)
    if args.no_exec:
        exec_result = (False, "Execution check skipped (--no-exec).")
    else:
        exec_result = execution_check(ctx, plugin_cache)

    expectations = eval_meta.get("expectations", [])
    results = []
    for exp in expectations:
        passed, evidence = grade_expectation(exp, ctx, exec_result)
        results.append({"text": exp, "passed": bool(passed), "evidence": evidence})

    passed_n = sum(1 for r in results if r["passed"])
    total = len(results)
    grading = {
        "expectations": results,
        "summary": {
            "passed": passed_n,
            "failed": total - passed_n,
            "total": total,
            "pass_rate": round(passed_n / total, 4) if total else 0.0,
        },
        "execution_result": {"passed": exec_result[0], "evidence": exec_result[1]},
    }
    out_path = Path(args.json_out) if args.json_out else run_dir / "grading.json"
    out_path.write_text(json.dumps(grading, indent=2))
    print(f"[eval {eval_meta['eval_id']} {run_dir.parent.name}/{run_dir.name}] "
          f"{passed_n}/{total} pass ({grading['summary']['pass_rate']*100:.0f}%) "
          f"exec={'PASS' if exec_result[0] else 'FAIL'} -> {out_path}")


if __name__ == "__main__":
    main()
