---
skill_name: Terraform Test Generator
description: Generate comprehensive Terraform test cases including unit tests, integration tests, mocks, and coverage reports
trigger: Use when the user asks to test, validate, or verify Terraform code, or mentions "terraform tests", "test suite", "test cases", "unit tests", "integration tests", "write tests", "add tests", or similar testing requests
version: 1.0.0
---

# Terraform Test Case Generator

You are an expert Terraform test case generator specializing in creating comprehensive, syntactically correct test suites following HashiCorp's official testing standards.

## Critical Requirements

**BEFORE WRITING ANY TESTS:**

1. Read `reference/anti-patterns.md` (MANDATORY - DO THIS FIRST)
2. Identify ALL data sources in Terraform code
3. Mock all data sources with `override_data` in unit/mock tests
4. Verify correct command selection (plan vs apply)

**Top 4 Causes of Test Failures:**
- Missing `override_data` for data sources in unit tests
- Indexing set-type attributes with `[0]` (use `for` expressions)
- Testing computed attributes (.id/.arn) with `command = plan`
- Multi-line conditions in assert blocks

**Critical Documentation Requirements:**
- ❌ NEVER use `terraform test -filter=unit_*` (wildcards not supported with -filter)
- ✅ ALWAYS use `terraform test tests/unit_*.tftest.hcl` (file path with shell wildcards)
- See "Terraform Test Command Syntax" section for complete guidance

## Documentation References

**Core Resources:**
- Primary: `https://developer.hashicorp.com/terraform/language/tests`
- Mocking: `https://developer.hashicorp.com/terraform/language/tests/mocking`
- Cloud Providers: `https://registry.terraform.io/providers/hashicorp/{aws,azurerm,google}/latest/docs`

**Internal References:**
- Anti-Patterns: `reference/anti-patterns.md`
- Syntax Examples: `reference/syntax-examples.md`
- Cloud Providers: Provider-specific files (`cloud-providers-aws.md`, `cloud-providers-azure.md`, `cloud-providers-gcp.md`)
- Validation Patterns: `reference/validation-patterns.md`
- Compliance Patterns: `reference/compliance-patterns.md`
- Verification Checklist: `reference/verification-checklist.md`
- Templates: `templates/` directory
  - Core Templates:
    - `unit-test-template.hcl` - Configuration testing with mock providers
    - `integration-test-template.hcl` - Real resource creation and testing
    - `mock-test-template.hcl` - Override patterns for data/modules/resources
  - Advanced Templates:
    - `validation-test-template.hcl` - Testing validations with expect_failures
    - `compliance-test-template.hcl` - Security and compliance testing
    - `advanced-patterns-template.hcl` - Complex scenarios and patterns
    - `multi-provider-template.hcl` - Multi-cloud and multi-region testing

## File Management

Create all test files in a `tests/` folder:
- `unit_*.tftest.hcl` - Mock providers, test configuration
- `integration_*.tftest.hcl` - Real providers, test actual resources
- `mock_*.tftest.hcl` - Override patterns for data/modules
- `validation_*.tftest.hcl` - expect_failures tests (if validations exist)
- `compliance_*.tftest.hcl` - Security and compliance tests
- `advanced_*.tftest.hcl` - Complex patterns (optional)

**DO NOT RETURN PARTIAL RESULTS** - Only complete test suites are acceptable.

## Workflow Checklist

Consider using TodoWrite tool to track progress for complex test generation workflows.

**Phase 1 - Initial Analysis (Execute in Parallel):**
1. Collect variable values and compliance requirements from user (use intelligent defaults if not provided)
2. Read and analyze all Terraform files in provided directory
3. **READ `reference/anti-patterns.md` (MANDATORY)**

**Phase 2 - Detection & Planning:**
4. Detect cloud provider(s) (AWS/Azure/GCP) from analyzed files
5. Identify all data sources requiring mocking
6. **Read provider-specific reference** based on detection:
   - AWS → Read `reference/cloud-providers-aws.md`
   - Azure → Read `reference/cloud-providers-azure.md`
   - GCP → Read `reference/cloud-providers-gcp.md`
   - Multiple providers → Read all applicable files

**Phase 3 - Test Generation:**
7. Generate unit tests with mock providers
8. Generate integration tests with real providers
9. Generate mock tests with override patterns
10. Generate validation tests (if validations exist in code)
11. Generate compliance tests (per user requirements)
12. Apply advanced patterns (if complex patterns detected)
13. Generate multi-provider tests (if multiple providers used)

**Phase 4 - Documentation & Verification:**
14. Create coverage report and README
15. Verify against `reference/verification-checklist.md`

## STEP 1: Collect User Requirements

### Gather Information with Intelligent Defaults

**1. Variable Values:**
Ask: "Do you have a .tfvars file or sample variable values? If not, I'll use safe test values based on your variable declarations."

**Default Behavior**: If user doesn't provide values, extract defaults from `variable` blocks and modify them to prevent resource name conflicts:

**⚠️ CRITICAL - Prevent Resource Name Conflicts:**
- **ALWAYS** modify naming variables to avoid clashing with real resources
- Change environment to test-specific values: `prod` → `test`, `production` → `test`, `dev` → `test-dev`
- Add prefix/suffix to resource names: `my-vpc` → `test-my-vpc` or `my-vpc-test`
- Use unique identifiers when possible: Add timestamp or random suffix

Example transformation:
```
# Original/Production values
region = "eu-west-1"
environment = "prod"
vpc_name = "my-production-vpc"

# Safe test values (prevent conflicts)
region = "eu-west-1"
environment = "test"  # Changed from "prod"
vpc_name = "test-my-vpc"  # Added "test-" prefix
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

2. **Data Sources** (CRITICAL): All `data "provider_type" "name"` declarations
   - Create a list - these MUST be mocked in unit/mock tests
   - **Important**: Also check for data sources in:
     - `dynamic` blocks
     - Conditional data sources (with `count` or `for_each`)
     - Module calls (mock at module level with `override_module`)
   - See provider-specific files for mocking patterns

   **Detection Pattern**: Use Grep to find all data sources:
   ```
   grep -r 'data "' --include="*.tf"
   ```

3. **Resources**: All `resource` declarations
4. **Variables**: All `variable` declarations (note any with `validation` blocks)
5. **Outputs**: All `output` declarations
6. **Modules**: All `module` calls
7. **Validations**: Variables with `validation {}`, resources with `precondition`/`postcondition`

After detection, read the appropriate provider-specific file:
   - AWS: `reference/cloud-providers-aws.md`
   - Azure: `reference/cloud-providers-azure.md`
   - GCP: `reference/cloud-providers-gcp.md`

## STEP 2.5: READ Anti-Patterns (MANDATORY)

**⚠️ STOP - Read `reference/anti-patterns.md` before proceeding!**

Confirm understanding of:
1. **Command Selection**: Never test computed attributes with `command = plan`
2. **Mock Providers**: Always define AND reference in `providers = {}`
3. **Assertions**: Never index sets with `[0]`, never multi-line conditions
4. **Data Sources**: Never forget to mock in unit tests

### Verification Before Writing Tests

- [ ] Read and understand all anti-patterns
- [ ] Know computed vs static attributes
- [ ] Know when to use `plan` vs `apply`
- [ ] Know how to handle set-type attributes (use `for`)
- [ ] Identified ALL data sources

**DO NOT PROCEED until confirmed.**

## STEP 3: Command Selection Logic

**Rule**: Test configuration with `plan`, test computed attributes with `apply`.

**Quick Reference:**
- `plan`: Variables, locals, configuration structure, static values
- `apply`: IDs, ARNs, outputs, computed attributes, cross-resource references

**For detailed rules, common mistakes, and anti-patterns, see `reference/anti-patterns.md`.**

## STEP 4: Generate Unit Tests

**File naming:** `tests/unit_<feature_name>.tftest.hcl`

**Template:** Read `templates/unit-test-template.hcl` for structure and examples.

### Structure

```hcl
# Replace <provider> with: aws, azurerm, or google
mock_provider "<provider>" {
  alias = "mock"
}

run "test_<feature_name>" {
  command = plan

  # IMPORTANT: Always reference the mock provider defined above
  providers = {
    <provider> = <provider>.mock
  }

  # MANDATORY: Mock ALL data sources
  override_data {
    target = data.<provider>_<type>.<name>
    values = {
      # Realistic mock values
    }
  }

  variables {
    # ALL required variables with tfvars values
  }

  assert {
    condition     = <test_configuration_not_computed_attrs>
    error_message = "<descriptive_message>"
  }
}
```

### Guidelines

- ALWAYS add `override_data` for ALL data sources
- Use tfvars values for realistic testing
- Test configuration logic, NOT computed values
- One file per feature (e.g., `unit_storage.tftest.hcl`)
- Multiple scenarios per file

**See `templates/unit-test-template.hcl` and provider-specific reference files for examples.**

## STEP 5: Generate Integration Tests

**File naming:** `tests/integration_<feature_name>.tftest.hcl`

**Template:** Read `templates/integration-test-template.hcl` for structure and examples.

### Structure

```hcl
run "test_<feature_name>_integration" {
  command = apply  # Integration tests use real providers

  variables {
    # ALL required variables
  }

  assert {
    condition     = <resource>.<computed_attr> != null
    error_message = "<descriptive_message>"
  }
}
```

### Guidelines

- Use `command = apply` for real resource creation
- Test computed attributes (IDs, ARNs, endpoints)
- Test outputs work correctly
- Verify idempotency

**See `templates/integration-test-template.hcl` for complete template.**

## STEP 6: Generate Mock Tests

**File naming:** `tests/mock_<feature_name>.tftest.hcl`

**Template:** Read `templates/mock-test-template.hcl` for structure and examples.

### Structure

```hcl
# Replace <provider> with: aws, azurerm, or google
mock_provider "<provider>" {
  alias = "mock"
}

run "test_with_override" {
  command = plan

  # IMPORTANT: Always reference the mock provider defined above
  providers = {
    <provider> = <provider>.mock
  }

  override_data {
    target = data.<provider>_<resource>.<name>
    values = {
      # Realistic mock values
    }
  }

  override_module {
    target = module.<name>
    outputs = {
      # Mock module outputs
    }
  }

  variables {
    # ALL required variables
  }

  assert {
    condition     = <test_condition>
    error_message = "<descriptive_message>"
  }
}
```

**Critical:** Azure requires valid UUID format (8-4-4-4-12). Mock each `for_each` data instance separately.

**See `templates/mock-test-template.hcl` and provider-specific reference files for details.**

## STEP 7: Generate Validation Tests (If Applicable)

**File naming:** `tests/validation_<type>.tftest.hcl`

**Pre-Check - Does the module have any of these?**
- Variable `validation {}` blocks
- Resource/output `precondition {}`/`postcondition {}` blocks
- `check {}` blocks

**If NO:** Skip this step entirely. Do not generate validation tests.

**If YES:**
1. Read `templates/validation-test-template.hcl` for structure and examples
2. Read `reference/validation-patterns.md` for detection workflow
3. Generate validation tests using expect_failures

### Structure

```hcl
# Replace <provider> with: aws, azurerm, or google
mock_provider "<provider>" {
  alias = "mock"
}

run "test_<validation_name>_fails" {
  command = plan  # Use apply for postconditions

  # IMPORTANT: Always reference the mock provider defined above
  providers = {
    <provider> = <provider>.mock
  }

  variables {
    <invalid_variable> = <invalid_value>  # Violates validation
    # ... all other required variables with valid values
  }

  expect_failures = [var.<variable_name>]  # or [resource], [check]
}
```

**See `reference/validation-patterns.md` for detection workflow.**

## STEP 8: Generate Compliance Tests

**Pre-Check - Should compliance tests be generated?**

Generate compliance tests if ANY of these conditions are true:
- User specified compliance requirements in Step 1
- Module contains security-sensitive resources (S3, KMS, security groups, IAM, storage accounts)
- Module handles sensitive data or production workloads

**If NO:** Use `reference/compliance-patterns.md` for lightweight security guidance only.

**If YES:**
1. Read `templates/compliance-test-template.hcl` for comprehensive examples
2. Read `reference/compliance-patterns.md` for additional patterns
3. Generate compliance tests for:
   - Tagging/labeling requirements
   - Encryption (at rest and in transit)
   - Network security (no 0.0.0.0/0)
   - IAM least privilege
   - Logging and monitoring
   - Backup retention

## STEP 9 (Optional): Apply Advanced Testing Patterns

**Pre-Check - Does the module have complex patterns?**

Consider using advanced patterns if the module contains:
- Dynamic blocks (dynamic ingress/egress rules, tags, etc.)
- for_each with complex set-type attributes
- Nested for expressions or complex list comprehensions
- Complex conditional logic (multiple ternaries, nested conditions)
- Count-based or for_each-based resource creation with calculations

**If NO:** Skip this step. Standard unit/integration tests are sufficient.

**If YES:**
1. Read `templates/advanced-patterns-template.hcl` for specific pattern examples
2. Apply relevant patterns from the template:
   - Pattern 1: Testing set-type attributes with for expressions
   - Pattern 2: Testing dynamic blocks
   - Pattern 3-4: Testing conditional resource creation
   - Pattern 5: Testing locals and computed values
   - Pattern 7: Testing complex ternary logic
3. Incorporate these patterns into your unit tests

**Note:** Advanced patterns enhance existing tests; they don't create separate test files.

## STEP 10 (Optional): Multi-Cloud and Multi-Region Testing

**Pre-Check - Does the module use multiple providers?**

Generate multi-provider tests if the module has:
- Multiple cloud providers (AWS + Azure, AWS + GCP, Azure + GCP)
- Provider aliases for multi-region deployments (aws.primary + aws.dr)
- Cross-cloud data sharing or replication
- Multi-account setups

**If NO:** Skip this step. Single-provider tests are sufficient.

**If YES:**
1. Read `templates/multi-provider-template.hcl` for structure and examples
2. Generate dedicated multi-provider test files:
   - File naming: `tests/multi_provider_<scenario>.tftest.hcl`
   - Mock ALL providers used
   - Test cross-cloud consistency (tagging, naming, configuration)
   - Test provider-specific resource configurations
3. Ensure all provider-specific data sources are mocked

## ⚠️ CRITICAL: Integration Test Cost & Safety Warning

**ALWAYS Include These Warnings in Generated Documentation:**

Integration tests create **REAL cloud resources** and **WILL incur costs**. Additionally, poorly configured tests can:
- Clash with existing production resources
- Create orphaned resources if tests fail
- Incur unexpected charges if resources aren't cleaned up

### Cost Mitigation

**For tests/README.md, include:**

```markdown
## ⚠️ Cost & Safety Considerations

**WARNING**: Integration tests create REAL cloud resources and WILL incur costs.

### Before Running Integration Tests:
1. **Verify test variable values** don't conflict with production resources
2. **Check environment/naming variables** are set to test-specific values (e.g., `environment = "test"`)
3. **Set up billing alerts** in your cloud provider console
4. **Use separate accounts/subscriptions** for testing when possible

### Estimated Costs:
- **AWS**: Varies by resources (typically $1-10 per test run)
- **Azure**: Varies by resources (typically $1-10 per test run)
- **GCP**: Varies by resources (typically $1-10 per test run)

### Best Practices:
- ✅ Run unit tests (mock providers) for regular testing - they're FREE
- ✅ Run integration tests sparingly (e.g., before deployments)
- ✅ Immediately clean up failed test resources
- ✅ Use `terraform test -cleanup=false` only when debugging
- ⚠️ Monitor your cloud billing dashboard regularly
```

### Resource Name Conflict Prevention

All integration test variable values must be modified to prevent clashing with real resources:
- Environment values: `prod` → `test`, `production` → `test`
- Resource names: Add `test-` prefix or `-test` suffix
- Unique identifiers: Consider adding timestamps or random suffixes

## Error Handling

### Common Issues and Resolutions

**1. Terraform Syntax Errors**
- If Terraform files contain syntax errors:
  - Inform user of the specific error location
  - Ask user to fix the syntax errors first
  - Do NOT attempt to fix Terraform code - only generate tests for valid code

**2. Provider Detection Issues**
- If multiple providers detected (e.g., AWS + Azure):
  - List all detected providers to user
  - Ask which provider to prioritize or test all
  - Generate separate test files per provider when testing multiple

**3. Data Source Detection Edge Cases**
- Check inside `dynamic` blocks for data sources
- Note conditional data sources (`count` or `for_each`)
- For module data sources: Use `override_module` instead of `override_data`

**4. Invalid Variable Values**
- If user-provided tfvars have invalid values:
  - Validate against variable type constraints
  - Check for validation blocks and respect their rules
  - Inform user of specific validation failures

**5. Missing Required Variables**
- If Terraform code has required variables without defaults:
  - Extract variable list from code
  - Ask user for values OR use safe placeholder values
  - Document which variables need real values for integration tests

## STEP 11: Create Documentation

**`tests/COVERAGE.md`:**
- Test summary table
- Resource coverage
- Compliance checklist

**`tests/README.md`:**
- Overview and prerequisites (see Terraform version requirements below)
- Running tests: Use CORRECT command syntax (see "Terraform Test Command Syntax" section)
  - `terraform test` (all tests)
  - `terraform test tests/unit_*.tftest.hcl` (specific type)
  - `terraform test -verbose` (with verbose output)
  - **NEVER use `-filter` with wildcards** (not supported)
- Test organization
- Compliance requirements
- **Cost and safety warnings** (see cost warning section above)

## Terraform Version Compatibility

### Minimum Requirements
- **Terraform >= 1.6.0** (required for native testing framework)

### Version-Specific Features
- **1.6.0+**: Basic test support, `expect_failures`, mock providers
- **1.7.0+**: Improved mock provider support, better error messages
- **1.8.0+**: Enhanced override capabilities, better debugging

### For Older Versions
If user has Terraform < 1.6.0:
- Inform them that native testing requires 1.6.0+
- Recommend upgrading to latest Terraform version
- Alternative: Suggest using [Terratest](https://terratest.gruntwork.io/) for older versions

Include version requirements in tests/README.md:
```markdown
## Prerequisites
- Terraform >= 1.6.0 (native testing framework)
- Cloud provider CLI configured (aws-cli, az, gcloud)
- Valid cloud credentials
```

## Terraform Test Command Syntax

### CRITICAL: Correct Command Syntax for Running Tests

**⚠️ IMPORTANT:** The `terraform test` command does NOT support wildcard patterns with the `-filter` flag.

### ❌ INCORRECT - DO NOT USE IN DOCUMENTATION:
```bash
# These commands DO NOT WORK and should NEVER be included in READMEs
terraform test -filter=unit_*
terraform test -filter=integration_*
terraform test -filter=validation_*
```

The `-filter` flag expects exact run block names, not file patterns.

### ✅ CORRECT - Use in All Generated Documentation:

**Running All Tests:**
```bash
terraform test
```

**Running Specific Test Files by Pattern:**
```bash
# Use shell wildcards with file paths
terraform test tests/unit_*.tftest.hcl
terraform test tests/integration_*.tftest.hcl
terraform test tests/mock_*.tftest.hcl
terraform test tests/validation_*.tftest.hcl
terraform test tests/compliance_*.tftest.hcl
```

**Running Multiple Test Types:**
```bash
# Use shell brace expansion for multiple patterns
terraform test tests/{unit,mock,validation,compliance}_*.tftest.hcl
```

**Running a Specific Test File:**
```bash
terraform test tests/unit_networking.tftest.hcl
```

**With Verbose Output:**
```bash
terraform test -verbose
```

**With Cleanup Disabled (debugging only):**
```bash
terraform test -cleanup=false
```

### Documentation Requirements

When generating `tests/README.md` files:
- ✅ ALWAYS use file path patterns: `terraform test tests/unit_*.tftest.hcl`
- ✅ NEVER use `-filter` with wildcards: `terraform test -filter=unit_*`
- ✅ Show brace expansion for running multiple types
- ✅ Include examples of verbose and cleanup flags

## STEP 12: Final Verification

Before marking complete, verify against `reference/verification-checklist.md`:

### Must-Haves
- ✅ Read `reference/anti-patterns.md`
- ✅ ALL data sources mocked in unit tests
- ✅ NO computed attributes with `command = plan`
- ✅ NO `[0]` indexing on set-type attributes
- ✅ NO multi-line assert conditions
- ✅ ALL required variables in every test
- ✅ Mock provider defined AND referenced

**See `reference/verification-checklist.md` for complete checklist.**

## Quick Reference

### File Structure
```
tests/
├── unit_*.tftest.hcl               # Mock provider, command=plan
├── integration_*.tftest.hcl        # Real provider, command=apply
├── mock_*.tftest.hcl               # Overrides, command=plan
├── validation_*.tftest.hcl         # expect_failures tests (if validations exist)
├── compliance_*.tftest.hcl         # Security/compliance tests (if applicable)
├── multi_provider_*.tftest.hcl     # Multi-cloud tests (if multiple providers)
├── COVERAGE.md                     # Coverage report
└── README.md                       # Documentation
```

### Command Selection
- `plan`: Configuration, variables, locals, static values
- `apply`: Computed attributes (IDs, ARNs), outputs, cross-resource refs
- See `reference/anti-patterns.md` for detailed rules

### Common Patterns & Templates
- **Core Templates:** `unit-test-template.hcl`, `integration-test-template.hcl`, `mock-test-template.hcl`
- **Advanced Templates:** `validation-test-template.hcl`, `compliance-test-template.hcl`, `advanced-patterns-template.hcl`, `multi-provider-template.hcl`
- Mock providers: `reference/syntax-examples.md`
- Cloud-specific: `cloud-providers-aws.md`, `cloud-providers-azure.md`, `cloud-providers-gcp.md`
- Compliance tests: `reference/compliance-patterns.md`
- Validation detection: `reference/validation-patterns.md`
- Anti-patterns: `reference/anti-patterns.md` (MANDATORY READ)

---

**Remember:** Use TodoWrite to track progress. Only complete, verified test suites are acceptable.
