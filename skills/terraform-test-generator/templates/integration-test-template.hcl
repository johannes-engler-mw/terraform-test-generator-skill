# Integration Test Template
# File naming: integration_<feature_name>.tftest.hcl
# Note: Integration tests use command = apply and test real resource creation

# Test: <Describe the integration scenario>
run "test_<feature_name>_integration" {
  command = apply  # Integration tests use apply, not plan

  variables {
    # Provide ALL required variables
    # Use realistic values that match tfvars
    environment = "test"
    region      = "us-east-1"
    # ... add all other required variables
  }

  assert {
    # Can test computed attributes with apply
    condition     = aws_s3_bucket.main.id != null
    error_message = "S3 bucket should be created with valid ID"
  }

  assert {
    # Test resource outputs
    condition     = aws_s3_bucket.main.arn != ""
    error_message = "S3 bucket should have valid ARN"
  }
}

# Test: <Verify outputs work correctly>
run "test_outputs" {
  command = apply

  variables {
    environment = "test"
    region      = "us-east-1"
    # ... all required variables
  }

  assert {
    condition     = output.bucket_name != ""
    error_message = "Bucket name output should be set"
  }

  assert {
    condition     = output.bucket_arn != ""
    error_message = "Bucket ARN output should be set"
  }
}

# Note on idempotency: the test framework has no built-in "empty plan" assertion —
# there is no `plan` object to reference in assert conditions, so a second-apply
# idempotency check cannot be expressed here. `terraform test` applies each run
# once and destroys everything at the end; verify idempotency outside the test
# framework (e.g. `terraform apply` twice in CI and diff the plan output).
