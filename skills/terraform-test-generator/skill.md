---
name: terraform-test-generator
description: Generates comprehensive Terraform/OpenTofu test cases including unit tests, integration tests, mocks, and coverage reports. Use when user asks to test, validate, or verify Terraform or OpenTofu code, or mentions terraform tests, test suite, unit tests, integration tests, or test cases.
version: 1.0.0
---

# Terraform/OpenTofu Test Case Generator

Expert test case generator for Terraform/OpenTofu following HashiCorp testing standards.

**OpenTofu:** Syntax identical to Terraform. Use `tofu test` instead of `terraform test`.

## Before You Start

Most Terraform-test bugs come from the same four mistakes:
- Missing `override_data` for data sources in unit tests
- Indexing set-type attributes with `[0]` (use `for` expressions)
- Testing computed attributes (`.id`, `.arn`) under `command = plan`
- Multi-line `assert` conditions

Read `reference/anti-patterns.md` before writing any tests — it explains each of these with examples. The cost is small compared to debugging a broken suite later.

For generated docs: use file-path patterns like `terraform test tests/unit_*.tftest.hcl`. Don't use `-filter`. Details in the "Test Command Syntax" section below.

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
- `mock_*.tftest.hcl` — overrides for data / modules / resources
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

**Environment value — depends on the module's validation block:**
- If the module restricts `var.environment` to a set like `["dev", "staging", "prod", "test"]`, pick `"test"` (it's the only safe choice in standard lists).
- If the module has no validation on environment, use `"tftest-<short-rand>"` (e.g. `"tftest-x9k2"`) — this is clearly synthetic and unlikely to collide with any real `Environment` tag.
- Bare `"test"` is risky as a universal default because many organizations use it as a real environment name.

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

**For detailed rules, common mistakes, and anti-patterns, see `reference/anti-patterns.md`.**

## STEP 4: Generate Unit Tests

**File naming:** `tests/unit_<feature_name>.tftest.hcl`

**Template:** `templates/unit-test-template.hcl`

**Key requirements:**
- Use `command = plan`
- Define `mock_provider` and reference it in each run's `providers = {}` block
- Mock every data source with `override_data` inside each `run` block (default — see note below)
- Test configuration logic, not computed values
- One file per feature with multiple scenarios

**`override_data` vs `mock_data` — when to pick which:**
- `override_data { target = data.X.Y ... }` lives inside a `run` block. Each scenario can mock different values, so this is the right default whenever your tests probe different conditions (different AZ counts, AMI variants, etc.).
- `mock_data "X" {...}` inside the `mock_provider` block is file-level — every run in that file sees the same mocked values. It's not wrong; it's the right choice when a data source's mock is genuinely uniform across all scenarios.
- Default to `override_data` because it scales as scenarios are added without restructuring the file. Use `mock_data` only when you've confirmed no scenario needs a per-run value.

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

**Pre-Check:** Only generate if module has `validation {}`, `precondition {}`, `postcondition {}`, or `check {}` blocks.

**If YES:**
1. Read `templates/validation-test-template.hcl`
2. Read `reference/validation-patterns.md`
3. Use `expect_failures` to test invalid inputs
4. Use `command = plan` for variable validations, `apply` for postconditions

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
- Running tests: file-path patterns only — `terraform test`, `terraform test tests/unit_*.tftest.hcl`, `terraform test -verbose`. See "Terraform/OpenTofu Test Command Syntax" below.
- Test organization
- Compliance requirements
- Cost and safety warnings (see cost warning section above)

After writing the README, grep it for `-filter` — if present, rewrite using file-path patterns. The `-filter` flag is for run-block name selection, not for file selection, and including it in user-facing docs leads readers to use it incorrectly.

## Terraform/OpenTofu Version Compatibility

### Minimum Requirements
- **Terraform >= 1.6.0** OR **OpenTofu >= 1.6.0** (required for native testing framework)

### Version-Specific Features
- **1.6.0+**: Basic test support, `expect_failures`, mock providers
- **1.7.0+**: Improved mock provider support, better error messages
- **1.8.0+**: Enhanced override capabilities, better debugging

**Note:** OpenTofu maintains compatibility with Terraform's testing framework. All features work identically.

### For Older Versions
If user has Terraform/OpenTofu < 1.6.0:
- Inform them that native testing requires 1.6.0+
- Recommend upgrading to latest version
- Alternative: Suggest using [Terratest](https://terratest.gruntwork.io/) for older versions

Include version requirements in tests/README.md:
```markdown
## Prerequisites
- Terraform >= 1.6.0 or OpenTofu >= 1.6.0 (native testing framework)
- Cloud provider CLI configured (aws-cli, az, gcloud)
- Valid cloud credentials
```

## Terraform/OpenTofu Test Command Syntax

For test selection in generated READMEs, use **file-path patterns**, not `-filter`. The `-filter` flag matches run-block names (not files), so file-path patterns are both clearer and shell-portable.

```bash
# Run everything
terraform test                                # or: tofu test

# Run by test type — use shell glob, not -filter
terraform test tests/unit_*.tftest.hcl        # or: tofu test tests/unit_*.tftest.hcl
terraform test tests/integration_*.tftest.hcl
terraform test tests/{unit,mock,validation,compliance}_*.tftest.hcl

# Useful flags
terraform test -verbose
terraform test -cleanup=false                 # debugging only
```

Always include both `terraform test` and `tofu test` forms in generated docs (they're interchangeable). Never emit `-filter` in a generated README — even with an exact name it's brittle and discourages glob-based selection.

## STEP 12: Final Verification

Before reporting the suite as complete, confirm:
- Anti-patterns reference was read
- Every data source is mocked in unit tests
- No `command = plan` block asserts on `.id` / `.arn` / other computed attributes
- No `[0]` indexing on set-type attributes (security_group ingress/egress)
- All assert conditions are single-line
- Every run block provides all required module variables
- Every unit-test run binds the mock provider via `providers = { ... }`
- The generated README contains no `-filter` invocations
- COVERAGE.md and README.md exist under `tests/`

If any check fails, fix it before returning the suite. Partial or unverified output forces the user to debug both their module and the generator.
