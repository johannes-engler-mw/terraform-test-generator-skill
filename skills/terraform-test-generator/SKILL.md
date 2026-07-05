---
name: terraform-test-generator
description: Generates comprehensive Terraform/OpenTofu test cases including unit tests, integration tests, mocks, and coverage reports. Use when user asks to test, validate, or verify Terraform or OpenTofu code, or mentions terraform tests, test suite, unit tests, integration tests, or test cases.
version: 1.0.0
---

# Terraform/OpenTofu Test Case Generator

Expert test case generator for Terraform/OpenTofu following HashiCorp testing standards.

**OpenTofu:** Syntax identical to Terraform. Use `tofu test` instead of `terraform test`.

## Before You Start

Most Terraform-test bugs come from the same five mistakes:
- Missing `override_data` for data sources in unit tests
- Indexing set-type attributes with `[0]` (use `for` expressions)
- Testing computed attributes (`.id`, `.arn`) under `command = plan`
- Multi-line `assert` conditions
- Top-level `locals {}` blocks in `.tftest.hcl` files — not a valid block type; `terraform init` rejects the whole suite. Shared values go in a top-level `variables {}` block instead

Read `reference/anti-patterns.md` before writing any tests — it explains each of these with examples. The cost is small compared to debugging a broken suite later.

For generated docs: select test files with `-filter=tests/<file>.tftest.hcl` — never positional paths (both tools silently ignore them and run the whole suite). Details in the "Test Command Syntax" section below.

## Reference Files

| File | Contents |
|------|----------|
| `reference/anti-patterns.md` | The four headline failures, plus mock-provider and documentation pitfalls |
| `reference/cloud-providers-{aws,azure,gcp,stackit}.md` | Provider-specific data-source mocking, common quirks |
| `reference/validation-patterns.md` | `expect_failures`, precondition/postcondition testing |
| `reference/compliance-patterns.md` | Encryption, tagging, network-security assertions |
| `templates/{unit,integration,mock,validation,compliance}-test-template.hcl` | Skeleton files for the common test types |
| `templates/advanced/` | Only read when applicable — `advanced-patterns-template.hcl` (dynamic blocks, nested for_each) and `multi-provider-template.hcl` (multi-cloud / provider aliases) |

Authoritative external docs: `https://developer.hashicorp.com/terraform/language/tests` and `…/tests/mocking`.

## File Layout

Put everything under a `tests/` folder. File names drive intent:
- `unit_*.tftest.hcl` — mock provider, `command = plan`, test configuration
- `integration_*.tftest.hcl` — real provider, `command = apply`, test actual resources
- `mock_*.tftest.hcl` — overrides for data / modules / resources (only if the module has data sources or module calls — see Step 6 pre-check)
- `validation_*.tftest.hcl` — `expect_failures` (only if the module has validation/precondition blocks)
- `compliance_*.tftest.hcl` — security and compliance assertions
- `advanced_*.tftest.hcl` — complex patterns (optional)

Always return a complete suite — half-finished output forces the user to debug both their code and your gaps.

## Workflow

Use TodoWrite to track progress on large modules.

1. Collect variable values and compliance requirements (defaults below).
2. Read and analyze all `.tf` files in the provided directory.
3. Read `reference/anti-patterns.md`.
4. Detect provider(s) and list data sources that need mocking.
5. Read the matching `reference/cloud-providers-*.md` file(s) for any detected provider.
6. Generate unit tests with mock providers.
7. Generate integration tests with real providers.
8. Generate mock tests with override patterns.
9. Generate validation tests if the module has `validation`/`precondition`/`postcondition`/`check` blocks.
10. Generate compliance tests per user requirements (defaults if none specified).
11. Apply advanced or multi-provider patterns if the module needs them.
12. Write COVERAGE.md and README.md.
13. Verify against the Final Verification checklist below.

## STEP 1: Collect User Requirements

### Gather Information with Intelligent Defaults

**1. Variable Values:**
Ask: "Do you have a .tfvars file or sample variable values? If not, I'll use safe test values based on your variable declarations."

**Default Behavior**: If the user doesn't provide values, extract defaults from `variable` blocks and transform them so the test suite cannot collide with real infrastructure if an integration test is run by accident.

**Environment value — read the variable's validation block first:**
- If `var.environment` has a validation block, the value MUST come from its allowed set. Pick `"test"` only if the set contains it; otherwise pick the least production-like allowed value (usually `"dev"`). A value outside the set — `"test"` against `["dev", "staging", "prod"]` is the classic case — fails every run in the suite at once.
- If the module has no validation on environment, use `"tftest-<short-rand>"` (e.g. `"tftest-x9k2"`) — this is clearly synthetic and unlikely to collide with any real `Environment` tag.
- Bare `"test"` is risky as a universal default: many organizations use it as a real environment name, and many validation lists don't include it.

**Resource names — always uniquify:**
- Add a `test-` prefix to every naming variable: `my-vpc` → `test-my-vpc`.
- Append a short random suffix when name collisions matter (e.g. globally unique buckets, DNS records): `test-my-bucket-x9k2`. This is the primary safety mechanism — real resources can't collide even if the env tag does.

Example transformation:
```
# Original/Production values
region      = "eu-west-1"
environment = "prod"
vpc_name    = "my-production-vpc"

# Safe test values
region      = "eu-west-1"
environment = "test"           # module validation accepts ["dev","staging","prod","test"]
vpc_name    = "test-my-vpc-x9k2"

# If the module had no env validation:
# environment = "tftest-x9k2"

# If the validation list were ["dev","staging","prod"] (no "test"):
# environment = "dev"
```

**2. Compliance Requirements:**
Ask: "What compliance requirements should I test? (e.g., tags, encryption, network security). If unsure, I'll include standard security best practices."

**Default Behavior**: If user says "none" or doesn't specify, use standard security best practices:
- Encryption at rest (storage, databases)
- Encryption in transit (SSL/TLS)
- No unrestricted network access (0.0.0.0/0)
- Resource tagging best practices

Examples of specific requirements:
- Mandatory tags: Environment, Project, Owner
- KMS encryption for storage
- IAM permissions boundaries
- Specific compliance frameworks (SOC 2, HIPAA, PCI-DSS)

**3. Terraform Code Path:**
User will provide the path to test.

## STEP 2: Analyze Terraform Code

Read all `.tf` files in the provided directory and identify:

1. **Provider(s)**:
   - AWS: `provider "aws"`, resources `aws_*`
   - Azure: `provider "azurerm"`, resources `azurerm_*`
   - GCP: `provider "google"`, resources `google_*`
   - STACKIT: `provider "stackit"`, resources `stackit_*`

2. **Data sources**: every `data "provider_type" "name"` block. These all need mocking in unit/mock tests. Use grep to enumerate:
   ```bash
   grep -r 'data "' --include="*.tf"
   ```
   Look inside `dynamic` blocks, conditional data sources (`count`/`for_each`), and module calls — for module data sources, mock at the module level with `override_module`.

3. **Resources**: All `resource` declarations
4. **Variables**: All `variable` declarations (note any with `validation` blocks)
5. **Outputs**: All `output` declarations
6. **Modules**: All `module` calls
7. **Validations**: Variables with `validation {}`, resources with `precondition`/`postcondition`

After detection, read the appropriate provider-specific file:
   - AWS: `reference/cloud-providers-aws.md`
   - Azure: `reference/cloud-providers-azure.md`
   - GCP: `reference/cloud-providers-gcp.md`
   - STACKIT: `reference/cloud-providers-stackit.md`

## STEP 3: Command Selection Logic

**Rule**: Test configuration with `plan`, test computed attributes with `apply`.

**Quick Reference:**
- `plan`: Variables, locals, configuration structure, static values
- `apply`: IDs, ARNs, outputs, computed attributes, cross-resource references

**Key nuance:** `command = apply` against a `mock_provider` creates **no real infrastructure** — the mock fabricates IDs/ARNs. Use mocked `apply` runs in unit tests to cover computed attributes for free; reserve real-provider `apply` for integration tests. (Terraform 1.9+ also supports `override_during = plan` on `override_*` blocks to make override values visible during plan; OpenTofu does not support it, so prefer mocked `apply` for portability.)

**For detailed rules, common mistakes, and anti-patterns, see `reference/anti-patterns.md`.**

## STEP 4: Generate Unit Tests

**File naming:** `tests/unit_<feature_name>.tftest.hcl`

**Template:** `templates/unit-test-template.hcl`

**Key requirements:**
- Use `command = plan` for configuration logic; use `command = apply` (still against the mock provider — creates nothing) for runs that assert on computed attributes
- Define `mock_provider` and reference it in each run's `providers = {}` block
- Mock every data source with `override_data` inside each `run` block (default — see note below)
- One file per feature with multiple scenarios

**`override_data` is the default; `mock_data` is a deliberate opt-in:**
- `override_data { target = data.X.Y ... }` goes inside each `run` block. Default to it: each run can mock different values, new scenarios slot in without restructuring the file, and the mock is always visible to the command that consumes it.
- `mock_data "X" {...}` inside the `mock_provider` block is file-level — every run in the file shares one set of values. Reach for it only after you've written the `override_data` form and confirmed no run will ever need a different value; if a later run does, you'll have to restructure the file to recover per-run variation. If you do use it, leave a comment naming why the value is uniform.

**See template and provider-specific reference files for complete examples.**

## STEP 5: Generate Integration Tests

**File naming:** `tests/integration_<feature_name>.tftest.hcl`

**Template:** `templates/integration-test-template.hcl`

**Key requirements:**
- Use `command = apply` (real providers, real resources)
- Test computed attributes (IDs, ARNs, endpoints)
- Test outputs and idempotency
- Include cost warnings in documentation

## STEP 6: Generate Mock Tests

**Pre-Check:** Only generate `mock_*.tftest.hcl` files if the module has **data sources or module calls** that need `override_data`/`override_module`. A module with neither (plain resources only) gets no mock file — the mock provider in the unit tests already covers it, and a separate mock file would only restate the unit tests. Do not over-generate.

**File naming:** `tests/mock_<feature_name>.tftest.hcl`

**Template:** `templates/mock-test-template.hcl`

**Key requirements:**
- Use `override_data` for data sources
- Use `override_module` for module outputs
- Use `override_resource` for specific resource values
- Azure: Valid UUID format (8-4-4-4-12)
- Mock each `for_each` instance separately

**See template and provider-specific reference files for complete patterns.**

## STEP 7: Generate Validation Tests (If Applicable)

**File naming:** `tests/validation_<type>.tftest.hcl`

**Pre-Check (mechanical, not a judgment call):** count the module's constraint blocks:

```bash
grep -cE 'validation \{|precondition \{|postcondition \{|check "' *.tf
```

Zero → generate no validation file. Greater than zero → a `validation_*.tftest.hcl` file is **required**, with at least one `expect_failures` run per constraint. A suite that skips it is incomplete.

**If YES:**
1. Read `templates/validation-test-template.hcl`
2. Read `reference/validation-patterns.md`
3. Use `expect_failures` to test invalid inputs
4. Use `command = plan` for variable validations, `apply` for postconditions
5. **Derive each invalid value from the constraint itself, then confirm it violates it.** For `^[a-z0-9]{3,15}$` an invalid-length value needs 16+ characters — a 13-character value passes and the `expect_failures` run fails because nothing failed. For `length(x) <= 32` use 33 characters. Never eyeball "looks invalid"; check the value against the regex/range before writing it.

## STEP 8: Generate Compliance Tests

**Pre-Check:** Generate if user specified requirements OR module has security-sensitive resources (S3, KMS, IAM, storage).

**If YES:**
1. Read `templates/compliance-test-template.hcl`
2. Read `reference/compliance-patterns.md`
3. Test: tagging, encryption, network security, IAM, logging, backups

## STEP 9 — Advanced patterns (rare; opt-in)

Skip this step for the vast majority of modules. **Only** if you've identified dynamic blocks, deeply nested `for_each`, or complex ternary logic that the standard templates don't cover, open `templates/advanced/advanced-patterns-template.hcl` for additional patterns and weave them into the existing unit/integration files (don't create a separate `advanced_*.tftest.hcl`).

If the module is straightforward — and most are — do not read this template. It exists for genuinely complex modules and adds noise otherwise.

## STEP 10 — Multi-cloud / provider aliases (rare; opt-in)

Skip this step unless the module declares more than one provider (e.g. both `aws` and `azurerm`) or uses provider aliases for multi-region. In that case, open `templates/advanced/multi-provider-template.hcl`, mock every provider, and write `tests/multi_provider_<scenario>.tftest.hcl` files that exercise cross-provider consistency.

A single-provider module needs nothing from this template — don't read it.

## Integration Test Cost & Safety Warning

Integration tests create real cloud resources and incur cost. The generated `tests/README.md` must include:
- A warning that integration tests provision real resources
- Pre-flight checks (verify variable values, set billing alerts, use a test account)
- Best practice: run unit tests for free, use integration tests sparingly, clean up after failures

Transform resource names to prevent conflicts with real infrastructure (prod→test, add `test-` prefix, use unique suffixes where appropriate).

## Error Handling

- **Syntax errors in the module:** report the location and ask the user to fix them first. Don't edit user Terraform — generate tests only against valid input.
- **Multiple providers detected:** list them and ask which to prioritize (or generate one test file set per provider).
- **Data sources in `dynamic` blocks, with `count`/`for_each`, or from modules:** mock them too. Module data sources use `override_module` instead of `override_data`.
- **Invalid `.tfvars` values:** validate against variable type constraints and `validation` blocks; report the specific failure.
- **Required variables without defaults:** ask the user for values, or use safe placeholders and document which variables need real values for integration tests.

## STEP 11: Create Documentation

**`tests/COVERAGE.md`:**
- Test summary table
- Resource coverage
- Compliance checklist

**`tests/README.md`:**
- Overview and prerequisites (see version compatibility below)
- Running tests: `terraform test` for everything, `-filter=tests/<file>.tftest.hcl` per file (repeat the flag for several files), `terraform test -verbose`. See "Terraform/OpenTofu Test Command Syntax" below.
- Test organization
- Compliance requirements
- Cost and safety warnings (see cost warning section above)

After writing the README, check every `terraform test`/`tofu test` invocation: file selection must go through `-filter=`. If any command passes test files as positional arguments (`terraform test tests/unit_x.tftest.hcl`), rewrite it — both tools silently ignore positional paths and run the **entire** suite, including apply-based integration tests that create real infrastructure.

Every `-filter=` path must also match where the files actually are, relative to the module root. Files belong in `tests/` (see File Layout), so the paths are `tests/<file>.tftest.hcl` — but verify with `ls` rather than assuming: a README that says `tests/unit_x.tftest.hcl` while the files sit flat next to `main.tf` documents commands that select nothing.

## Terraform/OpenTofu Version Compatibility

### Minimum Requirements
- **Terraform >= 1.7.0** OR **OpenTofu >= 1.7.0** — 1.6.0 introduced the test framework, but `mock_provider` and the `override_*` blocks (used by every generated unit/mock test) require 1.7.0.

### Version-Specific Features
- **1.6.0+**: Test framework, `expect_failures`
- **1.7.0+**: `mock_provider`, `override_data` / `override_module` / `override_resource`
- **1.9.0+ (Terraform only)**: `override_during = plan` on `override_*` blocks — makes override values visible during plan. OpenTofu (as of 1.11) rejects it; use mocked `command = apply` for portable suites.

**Note:** Apart from `override_during`, OpenTofu maintains compatibility with Terraform's testing framework.

### For Older Versions
If user has Terraform/OpenTofu < 1.7.0:
- Inform them that the generated suites need 1.7.0+ (mocking); 1.6.x can run only tests without `mock_provider`/`override_*`
- Recommend upgrading to latest version
- Alternative: Suggest using [Terratest](https://terratest.gruntwork.io/) for older versions

Include version requirements in tests/README.md:
```markdown
## Prerequisites
- Terraform >= 1.7.0 or OpenTofu >= 1.7.0 (native testing framework with mock providers)
- Cloud provider CLI configured (aws-cli, az, gcloud)
- Valid cloud credentials (integration tests only)
```

## Terraform/OpenTofu Test Command Syntax

For test selection in generated READMEs, use **`-filter=<path>`** — it is the documented file-selection flag in both tools. Never use positional file arguments: `terraform test tests/unit_x.tftest.hcl` is **silently ignored** (no error) and the entire suite runs, including apply-based integration tests that create real infrastructure.

```bash
# Run everything
terraform test                                # or: tofu test

# Run one file
terraform test -filter=tests/unit_networking.tftest.hcl

# Run several files — repeat the flag
terraform test -filter=tests/unit_networking.tftest.hcl -filter=tests/unit_storage.tftest.hcl

# POSIX-shell convenience only (not PowerShell-safe): expand a glob into repeated flags
terraform test $(printf -- '-filter=%s ' tests/unit_*.tftest.hcl)

# Useful flags
terraform test -verbose
```

In generated READMEs, **enumerate the actual generated files** with repeated `-filter` flags — you know their names, and explicit flags work in every shell. Mention the printf glob expansion at most as an aside. The `-filter` path is relative to the working directory. Always include both `terraform test` and `tofu test` forms in generated docs (flags are identical). There is no `-cleanup` flag in either tool — do not emit one.

## STEP 12: Final Verification

Before reporting the suite as complete, confirm:
- Anti-patterns reference was read
- Every data source is mocked in unit tests (via per-run `override_data`, by default)
- If the module has any `validation`/`precondition`/`postcondition`/`check` block, a `validation_*.tftest.hcl` with `expect_failures` exists (Step 7 pre-check count > 0 ⇒ file required)
- No `command = plan` block asserts on `.id` / `.arn` / other computed attributes
- No `[0]` indexing on set-type attributes (security_group ingress/egress, S3 SSE `rule` — see the known-sets list in `reference/anti-patterns.md`)
- All assert conditions are single-line
- No top-level `locals {}` block in any `.tftest.hcl` — `terraform init` rejects the block type and the whole suite fails. Shared values belong in a top-level `variables {}` block
- Every run block provides all required module variables
- Every unit-test run binds the mock provider via `providers = { ... }`
- No `mock_*.tftest.hcl` files exist unless the module has data sources or module calls
- No reference to `plan.resource_changes` anywhere — that's `terraform show -json` output, not a value tftest assertions can read
- COVERAGE.md and README.md exist under `tests/`

Then verify the README mechanically — self-review misses these:

```bash
grep -nE '(terraform|tofu) test +[^-]' tests/README.md   # every hit is a positional file/glob argument — rewrite with -filter=
grep -n 'cleanup' tests/README.md                        # -cleanup does not exist in either tool; delete any command that uses it
grep -oE 'filter=[^ `]+' tests/README.md | cut -d= -f2 | sort -u | xargs ls --   # every -filter path must name a real file
```

The first grep must return nothing except plain `terraform test` / `tofu test` (run-everything) lines. Positional paths **and globs** (`terraform test tests/unit_*.tftest.hcl`) are silently ignored — the whole suite runs, including apply-based integration tests. The `ls` in the third command must not error — run it from the module root so paths resolve the way a reader's would.

Also cross-check data-source mocking mechanically — a missed data source fails every run that plans it:

```bash
grep -hoE 'data "[^"]+" "[^"]+"' *.tf | sort -u                          # data sources the module declares
grep -hoE 'data\.[a-z0-9_]+\.[a-z0-9_]+' tests/*.tftest.hcl | sort -u    # data sources the tests mock/reference
```

Every entry from the first list must appear in the second as an `override_data` target (or `mock_data` block) in each non-integration file that exercises it.

**Then run the suite.** The checklist above is grep-based; it cannot catch the failures that matter most. From the module directory:

```bash
terraform init -backend=false
terraform test -filter=tests/unit_x.tftest.hcl -filter=tests/mock_x.tftest.hcl -filter=tests/validation_x.tftest.hcl -filter=tests/compliance_x.tftest.hcl
```

Pass one `-filter=tests/<file>.tftest.hcl` per non-integration file (skip `integration_*` — those need real credentials). Every run must finish with `passed`, zero failures. A red run is a bug in the generated suite, not an environment quirk: `Value not yet known` means a computed attribute leaked into a `plan` assertion; an `override_data` / missing-mock error means a data source wasn't mocked in that run. Fix the suite until it's green. The checklist exists to prevent these; the live run is the proof that it did.

If any check fails, fix it before returning the suite. Partial or unverified output forces the user to debug both their module and the generator.
