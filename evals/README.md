# Terraform Test Generator Skill — Evaluation Suite

This directory contains evaluation test cases for validating the `terraform-test-generator` skill using the [Claude Skill Creator](https://github.com/anthropics/skill-creator) framework.

## Overview

The eval suite tests the skill across 3 scenarios of varying complexity:

| Eval | Module | Provider | Complexity | Key Challenges |
|------|--------|----------|------------|----------------|
| 1 | AWS VPC + S3 + EC2 | AWS | High | 2 data sources, 11 variable validations, 1 precondition, dynamic blocks, conditional resources, KMS |
| 2 | Azure Resource Group + Storage | Azure | Medium | 1 data source, 3 variable validations, different provider detection |
| 3 | Simple S3 Bucket | AWS | Low | No data sources, no validations — tests lean output / avoids over-generation |

## Directory Structure

```
evals/
├── evals.json                          # Eval definitions with expectations
├── README.md                           # This file
└── test-modules/
    ├── eval-1-aws-vpc/                 # Complex AWS module (VPC, subnets, SG, S3, EC2, KMS)
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── eval-2-azure-storage/           # Medium Azure module (RG, Storage Account, Container)
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── eval-3-simple-s3/              # Simple AWS module (S3 bucket only)
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
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

**Key expectations (24 total):**
- Both data sources must be mocked with `override_data`
- No computed attributes tested with `command = plan`
- No `[0]` indexing on set-type attributes
- All assert conditions on single lines
- Test-safe variable values (environment = "test")
- README must not use `terraform test -filter` with wildcards

### Eval 2: Azure Storage Module (Medium)

**What it tests:**
- Azure provider detection (azurerm, not aws)
- Azure-specific reference loading (`cloud-providers-azure.md`)
- Azure data source mocking (`azurerm_client_config`) with valid UUIDs
- Variable validation detection and test generation
- Azure compliance patterns (TLS version, storage encryption)

**Key expectations (17 total):**
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

**Key expectations (13 total):**
- No `validation_*.tftest.hcl` files generated
- No `mock_*.tftest.hcl` files generated
- Test suite is lean but complete
- `bucket_name` variable provided in every test

## Expectations Format

Each eval has an `expectations` array in `evals.json`. These are plain-English assertions that can be verified either:
- **Programmatically** — by checking file contents (grep for patterns, count files)
- **By a grader agent** — reading outputs and verifying each statement

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

Good candidates for new evals:
- GCP module (tests `google` provider detection)
- Multi-provider module (tests cross-cloud handling)
- Module with external module calls (tests `override_module`)
- Module with `for_each` data sources (tests per-instance mocking)
- OpenTofu-specific request (tests `tofu test` command references)
