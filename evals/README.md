# Terraform Test Generator Skill — Evaluation Suite

This directory contains evaluation test cases for validating the `terraform-test-generator` skill using the [Claude Skill Creator](https://github.com/anthropics/skill-creator) framework.

## Overview

The eval suite tests the skill across 5 scenarios of varying complexity:

| Eval | Module | Provider | Complexity | Key Challenges |
|------|--------|----------|------------|----------------|
| 1 | AWS VPC + S3 + EC2 | AWS | High | 2 data sources, 11 variable validations, 1 precondition, dynamic blocks, conditional resources, KMS |
| 2 | Azure Resource Group + Storage | Azure | Medium | 1 data source, 3 variable validations, different provider detection |
| 3 | Simple S3 Bucket | AWS | Low | No data sources, no validations — tests lean output / avoids over-generation |
| 4 | GCP Storage + Service Account + IAM | GCP | Medium | CMEK encryption, labels (not tags), 5 variable validations, IAM binding checks |
| 5 | STACKIT ObjectStorage + Postgres Flex | STACKIT | Medium | Non-hyperscaler provider detection, project_id requirement, 3 variable validations |

All five modules pass `terraform init && terraform validate` — keep it that way: a module that doesn't validate can never have its generated tests executed. New eval modules must validate before being added.

## Directory Structure

```
evals/
├── evals.json                          # Eval definitions with expectations
├── README.md                           # This file
├── verify_eval.sh                      # Programmatic grader (file checks + execution check)
└── test-modules/
    ├── eval-1-aws-vpc/                 # Complex AWS module (VPC, subnets, SG, S3, EC2, KMS)
    ├── eval-2-azure-storage/           # Medium Azure module (RG, Storage Account, Container)
    ├── eval-3-simple-s3/               # Simple AWS module (S3 bucket only)
    ├── eval-4-gcp-storage-sa/          # Medium GCP module (CMEK bucket, SA, IAM bindings)
    └── eval-5-stackit-postgres/        # Medium STACKIT module (ObjectStorage, Postgres Flex)
        └── (each: main.tf, variables.tf, outputs.tf)
```

## How to Use

### With Claude Code (skill-creator)

If you have the `skill-creator` skill installed in Claude Code, you can run the full eval loop:

```
"Run the evals in evals/evals.json against the terraform-test-generator skill"
```

This will:
1. Spawn subagents for each eval (with-skill and baseline)
2. Grade outputs against the expectations
3. Generate a benchmark report and interactive viewer

### With Claude.ai

In Claude.ai (no subagents), ask Claude to:

```
"Test the terraform-test-generator skill using the evals in evals/evals.json. 
 For each eval, follow the skill instructions to generate tests for the 
 corresponding test module, then evaluate the output against the expectations."
```

Claude will run each eval sequentially, following the skill workflow, then present results for your review.

### Manual Evaluation

You can also evaluate manually:

1. Give Claude access to the skill (`skills/terraform-test-generator/`)
2. For each eval in `evals.json`, use the `prompt` as your request
3. Point Claude at the corresponding `test-modules/eval-N-*/` directory
4. Check the generated output against the `expectations` list

## Eval Details

### Eval 1: AWS VPC Module (Complex)

**What it tests:**
- Full workflow execution (all 12 steps in the skill)
- AWS provider detection and reference loading
- Data source mocking (`aws_availability_zones`, `aws_ami`)
- Variable validation test generation (11 validation blocks + 1 precondition)
- Dynamic block handling (security group ingress rules)
- Conditional resource handling (`create_instance`, `kms_key_id`)
- Set-type attribute handling (security group ingress — must NOT use `[0]`)
- Compliance test generation (encryption, tagging, network security)
- Documentation generation (README with correct command syntax, COVERAGE)

**Key expectations:**
- Both data sources mocked (any working mechanism — `override_data` or `mock_provider` `mock_data`)
- No computed attributes tested with `command = plan`
- No `[0]` indexing on set-type attributes
- Test-safe variable values (environment = "test")
- If docs show file-selecting test commands, they use `-filter=` (positional file arguments are silently ignored by terraform/tofu); vacuously true when no docs are produced
- Non-integration tests execute green (execution check)

### Eval 2: Azure Storage Module (Medium)

**What it tests:**
- Azure provider detection (azurerm, not aws)
- Azure-specific reference loading (`cloud-providers-azure.md`)
- Azure data source mocking (`azurerm_client_config`) with valid UUIDs
- Variable validation detection and test generation
- Azure compliance patterns (TLS version, storage encryption)

**Key expectations:**
- Provider correctly identified as azurerm
- `data.azurerm_client_config.current` mocked with valid UUIDs (8-4-4-4-12 format)
- Validation tests generated for the 3 variables with validation blocks
- Compliance tests check TLS 1.2 and encryption settings

### Eval 3: Simple S3 Bucket (Minimal)

**What it tests:**
- Appropriate scoping — skill should NOT over-generate
- No validation tests (module has no validation blocks)
- No mock data source tests (module has no data sources)
- Handles required variables without defaults (`bucket_name`)
- Still produces meaningful unit + compliance + integration tests

**Key expectations:**
- No validation tests generated (no `expect_failures` anywhere — content-based, not filename-based)
- No data-source mocking generated (no `override_data`/`mock_data` — the module has no data sources)
- Test suite is lean but complete (at most 4 test files)
- `bucket_name` variable provided in every test

### Eval 4: GCP Storage + Service Account (Medium)

**What it tests:**
- GCP provider detection (google, not aws/azurerm) and reference loading
- `data.google_project.current` mocking with `override_data`
- GCP-specific conventions: labels (not tags), lowercase enforcement
- Compliance: CMEK encryption, `uniform_bucket_level_access`, no allUsers/allAuthenticatedUsers IAM members
- Validation tests for all 5 variables with validation blocks

### Eval 5: STACKIT ObjectStorage + Postgres Flex (Medium)

**What it tests:**
- Non-hyperscaler provider detection (stackit) and reference loading
- `data.stackit_resourcemanager_project.current` mocking (the provider has no `stackit_project` data source)
- `project_id` present in every run block (STACKIT's signature requirement)
- Compliance: backup retention and version pinning
- Validation tests for project_id format, postgres_version enum, instance_name regex

## Expectations Format

Each eval has an `expectations` array in `evals.json`. These are plain-English assertions that can be verified either:
- **Programmatically** — `grade_run.py <run-dir>` is the canonical grader: deterministic per-expectation checks plus an **execution check** (all non-integration test files must pass `terraform test` against the module). `verify_eval.sh <eval-number> <tests-dir>` is a quick smoke-check subset. Execution is the strongest signal — grep checks can't catch parse errors, unknown-value failures under `plan`, or missing mocks.
- **By a grader agent** — reading outputs and verifying each statement

**Grade every run with `grade_run.py` (via `grade_all.py`), not with ad-hoc grader agents.** Iteration-8 was agent-graded and the execution expectation ended up judged under three different standards — actually executed (evals 2–3), structurally inferred (evals 1 and 5), and auto-failed for lack of results (eval-4, both arms) — which made the exec column incomparable across evals. Agent graders also misjudged `-filter=tests/…` paths that `grade_run.py` handles correctly (it flattens outputs into `tests/` before executing and only flags *positional* file args).

**Plugin cache must be warm before grading** or the execution check fails on provider download (this is what zeroed eval-4's exec results in iteration-8). `.tf-plugin-cache/` needs all four providers: `hashicorp/aws` (~>5.0), `hashicorp/azurerm` (~>3.0), `hashicorp/google` (~>5.0), `stackitcloud/stackit` (~>0.30). Pass it explicitly: `python3 grade_run.py <run-dir> --plugin-cache .tf-plugin-cache`.

### Fairness: quality criteria only

The rubric intentionally contains **no convention or deliverable-shape assertions**, so the with-skill vs. baseline comparison measures test quality, not adherence to the skill's own manual (iteration-7 analysis). Concretely:

- **Removed**: file-naming pattern (`unit_*`/`compliance_*` …), README/COVERAGE.md existence and contents, terraform/tofu command parity, 1.7.0 prerequisite wording, single-line assert style.
- **Reworded to functional**: data-source mocking accepts `override_data` *or* `mock_provider` `mock_data`; mock-provider usage accepts aliased (`providers = {...}` bound) *or* unaliased (default) form. The execution check proves whether the mocking works.
- **Conditional**: the `-filter=` check only applies *if* the output documents file-selecting test commands (positional paths are silently ignored by both tools — a genuine correctness trap — but docs themselves are not a graded deliverable).
- **Grader classification is content-based**: integration files are detected by real-provider `apply` content, compliance/unit checks fall back to scanning all non-integration content when the naming convention isn't used. A naming deviation costs nothing by itself.

Example expectation:
```json
"No computed attributes (.id, .arn) are tested with command = plan"
```

This can be verified by scanning all `*.tftest.hcl` files for `command = plan` blocks and ensuring none contain assertions on `.id` or `.arn` attributes.

## Adding New Evals

To add a new eval:

1. Create a new Terraform module in `test-modules/eval-N-<name>/`
2. Add an entry to `evals.json` with:
   - `id`: Next sequential integer
   - `prompt`: Realistic user request
   - `expected_output`: Human-readable description of success
   - `files`: List of input Terraform files (relative paths)
   - `expectations`: Verifiable assertions about the output

New eval modules must pass `terraform init && terraform validate` before being added — otherwise their generated tests can never be executed.

Good candidates for new evals:
- Multi-provider module (tests cross-cloud handling)
- Module with external module calls (tests `override_module` — currently uncovered)
- Module with `for_each` data sources (tests per-instance mocking)
- OpenTofu-specific request (tests `tofu test` command references)
