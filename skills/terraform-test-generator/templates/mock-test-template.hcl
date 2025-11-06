# Mock Test Template with Overrides
# File naming: mock_<feature_name>.tftest.hcl

# Define mock provider at file level
mock_provider "aws" {
  alias = "mock"
}

# Test: <Describe what data source or module is being mocked>
run "test_with_mocked_data_source" {
  command = plan

  providers = {
    aws = aws.mock  # REQUIRED even with overrides
  }

  # Override data source values
  override_data {
    target = data.aws_caller_identity.current
    values = {
      account_id = "123456789012"
      arn        = "arn:aws:iam::123456789012:root"
      user_id    = "AIDACKCEVSQ6C2EXAMPLE"
    }
  }

  variables {
    # Provide ALL required variables
    environment = "test"
    region      = "us-east-1"
    # ... all other required variables
  }

  assert {
    # Test that module USES the mocked data correctly
    # Example: Check if mocked account ID is used in resource naming/tagging
    condition     = can(regex("123456789012", aws_s3_bucket.main.bucket))
    error_message = "S3 bucket name should incorporate the mocked account ID"
  }

  assert {
    # Test that resources reference the mocked data source
    condition     = length(aws_iam_policy.main) > 0
    error_message = "IAM policy should be created based on mocked caller identity"
  }
}

# Test: <Mock module outputs>
run "test_with_mocked_module" {
  command = plan

  providers = {
    aws = aws.mock
  }

  # Override module outputs
  override_module {
    target = module.vpc
    outputs = {
      vpc_id             = "vpc-12345678"
      private_subnet_ids = ["subnet-123", "subnet-456"]
      public_subnet_ids  = ["subnet-789", "subnet-012"]
    }
  }

  variables {
    environment = "test"
    region      = "us-east-1"
    # ... all required variables
  }

  assert {
    # Test that resources USE mocked module outputs correctly
    # Example: Security group should reference the mocked VPC ID
    condition     = length(aws_security_group.app) > 0
    error_message = "Security group should be created using mocked VPC from module"
  }

  assert {
    # Test subnet references from mocked module
    condition     = alltrue([for instance in aws_instance.app : contains(["subnet-123", "subnet-456"], instance.subnet_id)])
    error_message = "Instances should be placed in subnets from mocked VPC module"
  }
}

# Test: <Mock resource with specific values>
run "test_with_mocked_resource" {
  command = plan

  providers = {
    aws = aws.mock
  }

  override_resource {
    target = aws_s3_bucket.dependency
    values = {
      id     = "mocked-bucket-id"
      arn    = "arn:aws:s3:::mocked-bucket"
      region = "us-east-1"
    }
  }

  variables {
    environment = "test"
    region      = "us-east-1"
    # ... all required variables
  }

  assert {
    # Test configuration that USES the mocked resource
    # Example: Bucket policy references the mocked bucket ID
    condition     = length(aws_s3_bucket_policy.main) > 0
    error_message = "Bucket policy should be configured for the mocked bucket"
  }

  assert {
    # Test that policy document references mocked bucket ARN
    condition     = can(regex("arn:aws:s3:::mocked-bucket", aws_s3_bucket_policy.main.policy))
    error_message = "Bucket policy should reference the mocked bucket ARN"
  }
}
