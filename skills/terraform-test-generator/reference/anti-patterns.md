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
    condition = aws_security_group.lambda_sg.name_prefix == "test"  # FAILS
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
run "test_resource_creation" {
  command = apply

  assert {
    condition = aws_s3_bucket.main.id != null  # OK with apply
    error_message = "Bucket should be created"
  }
}
```

## Mock Provider Anti-Patterns

### `mock_data` vs `override_data` — not a real anti-pattern

A common mistake when reading other people's tests is calling `mock_data` inside `mock_provider` "wrong". It isn't. The two mechanisms solve different problems:

| Mechanism | Scope | When it's right |
|-----------|-------|-----------------|
| `override_data { target = data.X.Y ... }` inside a `run` block | Per-scenario | Different runs need different mocked values (different AZ counts, AMI variants, region-specific responses). This is the default for generated tests because new scenarios can be added without restructuring the file. |
| `mock_data "X" {...}` inside `mock_provider {}` | File-level (all runs in the file) | Every run in the file sees the same mock values. Reduces repetition when there's no per-run variation. |

The generated test suite defaults to `override_data` for portability and easier evolution. Reach for file-level `mock_data` only when you've checked that no scenario needs a different value — otherwise you'll end up rewriting later.

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

### Anti-Pattern: multi-line `condition` expressions

`condition = ...` must be a single line. Terraform parses the assertion line-by-line and a multi-line expression silently breaks the assert.

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

For genuinely complex conditions, extract intermediate values into the module's `locals` and assert on those — both more readable and parseable.

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

### Anti-Pattern: Using `-filter` in generated READMEs

```bash
# ❌ WRONG — these encourage brittle test selection
terraform test -filter=unit_*
terraform test -filter=unit_vpc_networking.tftest.hcl
```

The `-filter` flag matches run-block *names*, not files. Even with an exact filename it works only by coincidence (if the run block happens to share the basename). Shell glob patterns on file paths are always clearer and more portable.

```bash
# ✅ CORRECT
terraform test                                # run everything
terraform test tests/unit_*.tftest.hcl        # run by type
```

Never emit `-filter` in user-facing documentation.

## Quick Reference: What to Test with Each Command

`command = plan` works on values Terraform knows before any provider call:
- Variables (`var.environment`), locals, static configuration values
- Structural assertions (`length(resource.rule) > 0`, key presence in tags)
- Conditional logic (`length(aws_kms_key.this) == 1` to verify a count-conditional resource exists)

`command = plan` fails on:
- Computed IDs (`.id`, `.arn`, `.self_link`)
- Cross-resource references whose target is computed (`aws_s3_bucket_versioning.this.bucket = aws_s3_bucket.this.id`)
- Anything only known after resource creation

`command = apply` covers everything `plan` does plus the computed attributes — but creates real resources, so reserve it for integration tests.

## Mandatory Pre-Generation Checklist

Before writing ANY assert statement, ask:

1. **Am I using `command = plan`?**
2. **If YES:** Am I testing a resource attribute?
3. **If YES to #2:** Is this attribute computed or does it reference another resource's ID/ARN?
4. **If YES to #3:** ⛔ STOP - This will fail!

**When in doubt:** Use `command = apply` for integration tests, or test configuration structure instead of computed attributes.
