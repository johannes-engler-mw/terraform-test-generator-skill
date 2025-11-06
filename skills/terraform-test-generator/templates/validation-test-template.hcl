# Validation Test Template
# File naming: validation_<feature_name>.tftest.hcl
# Note: Only generate validation tests if the module has validation/precondition/postcondition blocks

# Define mock provider at file level (replace with azurerm or google as needed)
mock_provider "aws" {
  alias = "mock"
}

# Test: Variable validation block failure
# Use when variable has validation { condition = ... } block
run "test_<variable_name>_validation_fails" {
  command = plan

  providers = {
    aws = aws.mock
  }

  # Mock all data sources (if any)
  override_data {
    target = data.aws_availability_zones.available
    values = {
      names    = ["us-east-1a", "us-east-1b"]
      zone_ids = ["use1-az1", "use1-az2"]
    }
  }

  variables {
    # Set the variable being tested to an INVALID value
    variable_name = "invalid-value"

    # ALL other required variables must have VALID values
    # This isolates the test to only the variable being validated
    environment = "dev"
    region      = "us-east-1"
    # ... all other required variables with valid values
  }

  # Expect the validation to fail on the specific variable
  expect_failures = [var.variable_name]
}

# Test: Resource precondition failure
# Use when resource has lifecycle { precondition { condition = ... } }
run "test_<resource>_precondition_fails" {
  command = plan

  providers = {
    aws = aws.mock
  }

  override_data {
    target = data.aws_availability_zones.available
    values = {
      names    = ["us-east-1a", "us-east-1b"]
      zone_ids = ["use1-az1", "use1-az2"]
    }
  }

  variables {
    # Set variable that violates the resource precondition
    enable_encryption = false  # Example: violates security precondition

    # All other variables valid
    bucket_name = "test-bucket"
    region      = "us-east-1"
    # ... all other required variables
  }

  # Expect the precondition to fail on the specific resource
  expect_failures = [aws_s3_bucket.main]
}

# Test: Output precondition failure
# Use when output has precondition { condition = ... }
run "test_<output>_precondition_fails" {
  command = plan

  providers = {
    aws = aws.mock
  }

  override_data {
    target = data.aws_availability_zones.available
    values = {
      names    = ["us-east-1a", "us-east-1b"]
      zone_ids = ["use1-az1", "use1-az2"]
    }
  }

  variables {
    # Set variable that violates the output precondition
    ssl_enforcement = false  # Example: violates security requirement

    # All other variables valid
    database_name = "test-db"
    region        = "us-east-1"
    # ... all other required variables
  }

  # Expect the precondition to fail on the specific output
  expect_failures = [output.database_endpoint]
}

# Test: Check block assertion failure
# Use when module has check { assert { condition = ... } }
run "test_<check_name>_fails" {
  command = plan

  providers = {
    aws = aws.mock
  }

  override_data {
    target = data.aws_availability_zones.available
    values = {
      names    = ["us-east-1a", "us-east-1b"]
      zone_ids = ["use1-az1", "use1-az2"]
    }
  }

  variables {
    # Set variable that violates the check assertion
    encryption_enabled = false  # Example: fails security compliance check

    # All other variables valid
    resource_name = "test-resource"
    region        = "us-east-1"
    # ... all other required variables
  }

  # Expect the check assertion to fail
  expect_failures = [check.security_compliance]
}

# Test: Resource postcondition failure
# Use when resource has lifecycle { postcondition { condition = ... } }
# IMPORTANT: Postconditions require command = apply (not plan)
run "test_<resource>_postcondition_fails" {
  command = apply  # Postconditions only evaluate after resource creation

  providers = {
    aws = aws.mock
  }

  variables {
    # Set variable that causes postcondition to fail after resource creation
    enable_versioning = false  # Example: violates post-creation check

    # All other variables valid
    bucket_name = "test-bucket"
    region      = "us-east-1"
    # ... all other required variables
  }

  # Expect the postcondition to fail on the specific resource
  expect_failures = [aws_s3_bucket.main]
}

# Test: Multiple validation failures
# Test that multiple invalid values each fail correctly
run "test_multiple_validations" {
  command = plan

  providers = {
    aws = aws.mock
  }

  override_data {
    target = data.aws_availability_zones.available
    values = {
      names    = ["us-east-1a", "us-east-1b"]
      zone_ids = ["use1-az1", "use1-az2"]
    }
  }

  variables {
    # Set multiple variables to invalid values
    name_too_short = "ab"  # Fails: length < 3
    invalid_port   = 99999  # Fails: port > 65535

    # All other variables valid
    environment = "dev"
    region      = "us-east-1"
    # ... all other required variables
  }

  # Can expect multiple failures in one test
  expect_failures = [
    var.name_too_short,
    var.invalid_port
  ]
}
