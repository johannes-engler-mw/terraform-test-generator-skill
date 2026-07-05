# Common Anti-Patterns to Avoid

## Table of Contents
- [Command Selection Anti-Patterns](#command-selection-anti-patterns)
- [Mock Provider Anti-Patterns](#mock-provider-anti-patterns)
- [Assertion Anti-Patterns](#assertion-anti-patterns)
- [Variable Testing Anti-Patterns](#variable-testing-anti-patterns)

## Command Selection Anti-Patterns

### Critical Rule
**NEVER TEST COMPUTED RESOURCE ATTRIBUTES WITH `command = plan`**

Even with `mock_provider`, computed attributes are only available after apply.

### Anti-Pattern: Testing Computed Attributes with Plan

```hcl
# ❌ WRONG - AWS
run "test_security_group" {
  command = plan  # Plan cannot access computed attributes

  assert {
    condition = aws_security_group.lambda_sg.arn != null  # FAILS - unknown during plan
    error_message = "This will always fail"
  }
}

# ❌ WRONG - Azure
run "test_storage_account" {
  command = plan

  assert {
    condition = azurerm_storage_account.main.id != null  # FAILS
    error_message = "This will always fail"
  }
}

# ❌ WRONG - GCP
run "test_storage_bucket" {
  command = plan

  assert {
    condition = google_storage_bucket.main.self_link != ""  # FAILS
    error_message = "This will always fail"
  }
}
```

**Why it fails:** Computed attributes like `.id`, `.arn`, `.self_link` are only available after resource creation (apply).

### Correct Approach

```hcl
# ✅ CORRECT - Test configuration, not computed values
run "test_configuration" {
  command = plan

  assert {
    condition = var.environment != ""  # Variables/locals only
    error_message = "Environment must be set"
  }
}

# ✅ CORRECT - Use apply for computed attributes
# Against a mock_provider this creates NO real infrastructure — the mock
# fabricates the computed values, so unit tests can use mocked apply for free.
run "test_resource_creation" {
  command = apply

  providers = {
    aws = aws.mock
  }

  assert {
    condition = aws_s3_bucket.main.id != null  # OK with apply
    error_message = "Bucket should be created"
  }
}
```

## Mock Provider Anti-Patterns

### `mock_data` vs `override_data` — default to `override_data`

Both mechanisms mock a data source; they differ in scope, and the scope is what trips people up:

| Mechanism | Scope | When it's right |
|-----------|-------|-----------------|
| `override_data { target = data.X.Y ... }` inside a `run` block | Per-run | **The default for generated tests.** Each run can mock different values (different AZ counts, AMI variants), new scenarios slot in without restructuring the file, and the mock is visible to the command that consumes it. |
| `mock_data "X" {...}` inside `mock_provider {}` | File-level (every run in the file) | A deliberate opt-in — only after you've written the `override_data` form and confirmed no run will ever need a different value. |

**Why default to `override_data`:** file-level `mock_data` pins one set of values across every run in the file. The moment a later run needs a different value (a different AMI, a one-AZ region, a paginated response), you have to restructure the file to recover per-run variation. Per-run `override_data` keeps each scenario self-contained, so adding a scenario never touches the others.

**Use file-level `mock_data` only when** you can name — in a comment next to the block — why the value is uniform across every run in the file. Otherwise reach for `override_data`.

### Anti-Pattern: Using Overrides Without Mock Provider

```hcl
# ❌ WRONG - No mock provider defined
run "test_with_override" {
  command = plan

  override_resource {
    target = aws_s3_bucket.main
    values = {
      id = "test-bucket"
    }
  }

  # This will FAIL - Terraform asks for AWS credentials
}
```

### Correct Approach

```hcl
# ✅ CORRECT - Define mock provider at file level
mock_provider "aws" {
  alias = "mock"
}

run "test_with_override" {
  command = plan

  providers = {
    aws = aws.mock  # REQUIRED
  }

  override_resource {
    target = aws_s3_bucket.main
    values = {
      id = "test-bucket"
    }
  }
}
```

### Anti-Pattern: Testing Computed References with Plan

Even with mocks, attributes that reference other resources fail with plan:

```hcl
# ❌ WRONG - AWS
run "test_encryption" {
  command = plan

  providers = {
    aws = aws.mock
  }

  assert {
    # FAILS: .bucket references aws_s3_bucket.main.id (computed)
    condition = aws_s3_bucket_server_side_encryption_configuration.main.bucket != null
    error_message = "This will fail"
  }
}

# ❌ WRONG - Azure
run "test_network_rule" {
  command = plan

  providers = {
    azurerm = azurerm.mock
  }

  assert {
    # FAILS: .resource_group_name references azurerm_resource_group.main.name (computed)
    condition = azurerm_network_security_rule.main.resource_group_name != ""
    error_message = "This will fail"
  }
}
```

### Correct Approach

```hcl
# ✅ CORRECT - Test configuration structure
run "test_encryption" {
  command = plan

  providers = {
    aws = aws.mock
  }

  assert {
    condition = length(aws_s3_bucket_server_side_encryption_configuration.main.rule) > 0
    error_message = "Encryption configuration should be present"
  }
}
```

## Assertion Anti-Patterns

### Anti-Pattern: `[0]` indexing on set-type attributes

Many resource attributes are sets, not lists — `security_group.ingress`, `security_group.egress`, `bucket.lifecycle_rule.transition`, and so on. Sets aren't ordered, so `set[0]` is not stable and Terraform rejects it. Use a `for` expression to filter instead.

```hcl
# ❌ WRONG — set indexing
assert {
  condition = aws_security_group.main.ingress[0].from_port == 443
  error_message = "Should allow HTTPS"
}

# ✅ CORRECT — for expression
assert {
  condition = length([for rule in aws_security_group.main.ingress : rule if rule.from_port == 443]) > 0
  error_message = "Should allow HTTPS"
}
```

The same rule applies to `egress`, SSE rule sets, and any nested set block. List-typed attributes (e.g. `versioning_configuration[0]`, `root_block_device[0]`) are fine to index — only sets are forbidden.

**Known set-type blocks — never `[0]` these:**

| Resource | Set-type attribute |
|----------|--------------------|
| `aws_security_group` | `ingress`, `egress` |
| `aws_s3_bucket_server_side_encryption_configuration` | `rule` (fails at runtime with `Cannot index a set value`) |

Schemas differ per provider — on `google_storage_bucket`, `encryption` and `versioning` are single-element **lists**, so `[0]` is valid there. When you aren't certain a nested block is a list, use the `for` expression: it is correct for both sets and lists, so it never needs the schema check.

### Anti-Pattern: multi-line `condition` expressions

Keep `condition = ...` on a single line. HCL rejects an expression that wraps across lines unless the break falls inside brackets or the whole expression is parenthesized — an unparenthesized line-wrap is a parse error. Single-line conditions keep generated suites uniform and greppable.

```hcl
# ❌ WRONG — line-wrapped condition
assert {
  condition = var.iam_role_prefix != "" ?
    can(regex("^arn:aws:iam::[0-9]+:policy/", data.aws_iam_policy.boundary[0].arn)) :
    true
  error_message = "Permissions boundary policy ARN should follow expected format"
}

# ✅ CORRECT — single line, even if long
assert {
  condition = var.iam_role_prefix != "" ? can(regex("^arn:aws:iam::[0-9]+:policy/", data.aws_iam_policy.boundary[0].arn)) : true
  error_message = "Permissions boundary policy ARN should follow expected format"
}
```

For genuinely complex conditions, extract intermediate values into the **module's** `locals` (in its `.tf` files) and assert on those — both more readable and parseable. Never add a `locals` block to the test file itself; see the next section.

### Anti-Pattern: top-level `locals {}` blocks in `.tftest.hcl` files

`locals` is not a valid block type in test files. `terraform init` fails with `Error: Unsupported block type` and the **entire suite** becomes unrunnable — one bad file blocks every test.

```hcl
# ❌ WRONG — locals is not a valid tftest block; init rejects the whole suite
locals {
  common_tags = {
    Environment = "test"
    Project     = "test-project"
  }
}

run "test_tags" {
  variables {
    tags = local.common_tags   # never evaluated — init already failed
  }
}

# ✅ CORRECT — shared values go in a top-level variables block
variables {
  tags = {
    Environment = "test"
    Project     = "test-project"
  }
}

run "test_tags" {
  # inherits file-level variables; override per-run as needed
}
```

Valid top-level blocks in a `.tftest.hcl` file: `run`, `variables`, `provider`, `mock_provider`, and the `override_*` blocks. Anything else (`locals`, `resource`, `output`) is a config-file construct and belongs in the module, not the test.

## Variable Testing Anti-Patterns

### Anti-Pattern: Testing Variable Against Itself

```hcl
# ❌ WRONG - Meaningless test
run "test" {
  variables {
    environment = "dev"
  }

  assert {
    condition = var.environment == "dev"  # You just set this!
    error_message = "Environment should be dev"
  }
}
```

### Correct Approach

```hcl
# ✅ CORRECT - Test logic/computation
run "test_security_group_logic" {
  variables {
    create_security_group = true
    additional_security_group_ids = ["sg-123"]
  }

  assert {
    # Tests the LOGIC: concat([aws_security_group.ec2[0].id], var.additional_ids)
    condition = var.create_security_group ? length(local.security_group_ids) >= 2 : length(local.security_group_ids) == 1
    error_message = "Security group IDs logic is incorrect"
  }
}
```

### Anti-Pattern: Static or Always-True Conditions

```hcl
# ❌ WRONG - Always true
assert {
  condition     = true
  error_message = "This test always passes"
}

# ❌ WRONG - Testing set value
run "test" {
  variables {
    instance_type = "t3.micro"
  }

  assert {
    condition = var.instance_type == "t3.micro"  # You just set this
    error_message = "Instance type should be t3.micro"
  }
}
```

## Azure-Specific Anti-Patterns

### Anti-Pattern: Invalid UUID Format

```hcl
# ❌ WRONG - Not valid UUIDs
override_data {
  target = data.azuread_group.admin_groups["TestGroup"]
  values = {
    object_id = "group-obj-id-12345"  # Not a valid UUID
  }
}

override_data {
  target = data.azurerm_client_config.current
  values = {
    tenant_id = "custom-tenant-id"  # Not a valid UUID
  }
}
```

### Correct Approach

```hcl
# ✅ CORRECT - Valid UUID format (8-4-4-4-12 hex digits)
override_data {
  target = data.azuread_group.admin_groups["TestGroup"]
  values = {
    display_name     = "TestGroup"
    object_id        = "11111111-1111-1111-1111-111111111111"
    security_enabled = true
  }
}

override_data {
  target = data.azurerm_client_config.current
  values = {
    tenant_id       = "87654321-4321-4321-4321-210987654321"
    subscription_id = "12345678-1234-1234-1234-123456789012"
  }
}
```

### Anti-Pattern: Missing override_data for for_each

```hcl
# ❌ WRONG - Missing mocks for data source
run "test_with_entra_groups" {
  providers = {
    azurerm = azurerm.mock
    azuread = azuread.mock_ad
  }

  variables {
    entra_id_admin_group_display_names = ["TestGroup"]
    # Missing: override_data for the group
  }

  # This will FAIL - UUID validation error
}
```

### Correct Approach

```hcl
# ✅ CORRECT - Mock each for_each instance
run "test_with_entra_groups" {
  providers = {
    azurerm = azurerm.mock
    azuread = azuread.mock_ad
  }

  override_data {
    target = data.azuread_group.admin_groups["TestGroup"]
    values = {
      display_name     = "TestGroup"
      object_id        = "11111111-1111-1111-1111-111111111111"
      security_enabled = true
    }
  }

  variables {
    entra_id_admin_group_display_names = ["TestGroup"]
  }
}
```

## Documentation Anti-Patterns

### Anti-Pattern: positional file arguments in generated READMEs

```bash
# ❌ WRONG — both tools silently IGNORE positional file arguments and run the ENTIRE suite
terraform test tests/unit_vpc_networking.tftest.hcl
terraform test tests/unit_*.tftest.hcl
```

There is no error: the command *appears* to work, but every test file runs — including `integration_*.tftest.hcl` files that `apply` real infrastructure. A reader following "run only the free unit tests" would create real resources and incur costs.

```bash
# ✅ CORRECT — -filter is the file-selection flag; repeat it for several files
terraform test                                                      # run everything
terraform test -filter=tests/unit_vpc_networking.tftest.hcl         # run one file
terraform test -filter=tests/unit_vpc.tftest.hcl -filter=tests/unit_sg.tftest.hcl   # run several
```

In generated READMEs, enumerate the actual files with repeated `-filter` flags (portable to every shell). For local POSIX-shell convenience a glob can expand into repeated flags — `terraform test $(printf -- '-filter=%s ' tests/unit_*.tftest.hcl)` — but don't make that the primary documented form.

Never emit positional test-file arguments in user-facing documentation. Also never emit `-cleanup=false` — no such flag exists in either tool.

## Quick Reference: What to Test with Each Command

`command = plan` works on values Terraform knows before any provider call:
- Variables (`var.environment`), locals, static configuration values
- Structural assertions (`length(resource.rule) > 0`, key presence in tags)
- Conditional logic (`length(aws_kms_key.this) == 1` to verify a count-conditional resource exists)

`command = plan` fails on:
- Computed IDs (`.id`, `.arn`, `.self_link`)
- Cross-resource references whose target is computed (`aws_s3_bucket_versioning.this.bucket = aws_s3_bucket.this.id`)
- Anything only known after resource creation

`command = apply` covers everything `plan` does plus the computed attributes. What it creates depends on the provider:
- Against a `mock_provider`: **nothing is created** — computed values are fabricated. Unit tests can use mocked `apply` runs to cover IDs/ARNs for free.
- Against a real provider: real resources and real costs — reserve for integration tests.

Terraform 1.9+ alternative: set `override_during = plan` on an `override_resource`/`override_data`/`override_module` block to make its `values` visible during plan. OpenTofu (as of 1.11) rejects `override_during`, so prefer mocked `apply` when the suite must run under both tools.

## Mandatory Pre-Generation Checklist

Before writing ANY assert statement, ask:

1. **Am I using `command = plan`?**
2. **If YES:** Am I testing a resource attribute?
3. **If YES to #2:** Is this attribute computed or does it reference another resource's ID/ARN?
4. **If YES to #3:** ⛔ STOP - This will fail!

**When in doubt:** Use a mocked `command = apply` run (creates nothing) for computed attributes, or test configuration structure under `plan` instead. Real-provider `apply` belongs only in integration tests.
