# Common Patterns Reference

## Set-Type Attributes

**CRITICAL:** Many resource attributes are sets, not lists. NEVER use index notation `[0]` on sets.

**Incorrect:**
```hcl
assert {
  condition = aws_security_group.main.ingress[0].from_port == 443
  error_message = "Should allow HTTPS"
}
```

**Correct:**
```hcl
assert {
  condition = length([for rule in aws_security_group.main.ingress : rule if rule.from_port == 443]) > 0
  error_message = "Should allow HTTPS"
}
```

## Mock Provider Pattern

**All providers (AWS/Azure/GCP/STACKIT) follow the same pattern:**

```hcl
# At file level
mock_provider "<provider>" {
  alias = "mock"
}

run "test_name" {
  command = plan

  # REQUIRED: Reference the mock provider
  providers = {
    <provider> = <provider>.mock
  }

  override_data {
    target = data.<provider>_<type>.<name>
    values = {
      # Provider-specific mock values
    }
  }

  variables {
    # All required variables
  }

  assert {
    condition     = <test_condition>
    error_message = "<descriptive_message>"
  }
}
```

## Command Selection Quick Reference

**Use `command = plan` to test:**
- ✅ Variables: `var.environment`
- ✅ Locals: `local.computed_value`
- ✅ Configuration structure: `length(resource.rule)`
- ✅ Static values: `resource.tags["Name"]`
- ✅ Conditional logic: `length(resource)` (tests if exists)

**CANNOT test with plan:**
- ❌ Computed IDs: `.id`
- ❌ Computed ARNs: `.arn`, `.self_link`
- ❌ Cross-resource refs when they reference computed values
- ❌ Any attribute that only exists after resource creation

**Use `command = apply` to test:**
- ✅ Everything from plan, PLUS
- ✅ Computed attributes after resource creation
- ✅ Resource IDs, ARNs, endpoints
- ✅ Outputs
- ✅ Cross-resource references

## Assert Statement Formatting

**All conditions MUST be on a single line:**

```hcl
# ✅ Correct - single line
assert {
  condition = var.iam_role_prefix != "" ? can(regex("^arn:aws:iam::[0-9]+:policy/", data.aws_iam_policy.boundary[0].arn)) : true
  error_message = "Permissions boundary policy ARN should follow expected format"
}

# ❌ Wrong - multi-line
assert {
  condition = var.iam_role_prefix != "" ?
    can(regex("^arn:aws:iam::[0-9]+:policy/", data.aws_iam_policy.boundary[0].arn)) :
    true
  error_message = "Error message"
}
```
