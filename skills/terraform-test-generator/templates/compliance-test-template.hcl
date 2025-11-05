# Compliance Test Template
# File naming: compliance_<feature_name>.tftest.hcl
# Tests security best practices, tagging, encryption, and compliance requirements

# Define mock provider at file level (replace with azurerm or google as needed)
mock_provider "aws" {
  alias = "mock"
}

# Test: Encryption at rest is enabled
run "test_encryption_at_rest" {
  command = plan

  providers = {
    aws = aws.mock
  }

  # Mock all data sources
  override_data {
    target = data.aws_availability_zones.available
    values = {
      names    = ["us-east-1a", "us-east-1b"]
      zone_ids = ["use1-az1", "use1-az2"]
    }
  }

  variables {
    # Provide ALL required variables
    project_name    = "test-app"
    environment     = "test"
    enable_encryption = true
    # ... all other required variables
  }

  # Test S3 bucket encryption
  assert {
    condition     = length([for rule in aws_s3_bucket_server_side_encryption_configuration.main.rule : rule if length([for default in rule.apply_server_side_encryption_by_default : default if default.sse_algorithm == "AES256" || default.sse_algorithm == "aws:kms"]) > 0]) > 0
    error_message = "S3 bucket must have encryption enabled (AES256 or KMS)"
  }

  # Test EBS volume encryption
  assert {
    condition     = length(aws_instance.main) == 0 || aws_instance.main[0].root_block_device[0].encrypted == true
    error_message = "EC2 root volumes must be encrypted"
  }
}

# Test: Mandatory tagging requirements
run "test_required_tags" {
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
    project_name = "test-app"
    environment  = "test"
    common_tags = {
      Environment = "test"
      Project     = "test-app"
      Owner       = "test-team"
      CostCenter  = "engineering"
    }
    # ... all other required variables
  }

  # Test VPC has required tags
  assert {
    condition     = contains(keys(aws_vpc.main.tags), "Environment") && contains(keys(aws_vpc.main.tags), "Project") && contains(keys(aws_vpc.main.tags), "Owner")
    error_message = "VPC must have Environment, Project, and Owner tags"
  }

  # Test S3 bucket has required tags
  assert {
    condition     = contains(keys(aws_s3_bucket.main.tags), "Environment") && contains(keys(aws_s3_bucket.main.tags), "Project") && contains(keys(aws_s3_bucket.main.tags), "Owner")
    error_message = "S3 bucket must have Environment, Project, and Owner tags"
  }

  # Test security group has required tags
  assert {
    condition     = contains(keys(aws_security_group.main.tags), "Environment") && contains(keys(aws_security_group.main.tags), "Project")
    error_message = "Security groups must have Environment and Project tags"
  }
}

# Test: Network security - no unrestricted access
run "test_no_unrestricted_access" {
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
    project_name          = "test-app"
    environment           = "test"
    allowed_cidr_blocks   = ["10.0.0.0/8", "172.16.0.0/12"]
    allowed_ingress_ports = [443, 22]
    # ... all other required variables
  }

  # Test security group doesn't allow 0.0.0.0/0 on sensitive ports
  assert {
    condition     = length([for rule in aws_security_group.main.ingress : rule if contains(rule.cidr_blocks, "0.0.0.0/0") && contains([22, 3389, 3306, 5432], rule.from_port)]) == 0
    error_message = "Security groups must not allow 0.0.0.0/0 access to sensitive ports (SSH, RDP, databases)"
  }

  # Test only specific CIDR blocks are allowed
  assert {
    condition     = alltrue([for rule in aws_security_group.main.ingress : alltrue([for cidr in rule.cidr_blocks : cidr != "0.0.0.0/0"])])
    error_message = "Security groups must not use unrestricted CIDR blocks (0.0.0.0/0)"
  }
}

# Test: S3 bucket security configuration
run "test_s3_bucket_security" {
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
    project_name = "test-app"
    environment  = "test"
    # ... all other required variables
  }

  # Test S3 bucket has versioning enabled
  assert {
    condition     = length([for config in aws_s3_bucket_versioning.main.versioning_configuration : config if config.status == "Enabled"]) > 0
    error_message = "S3 bucket must have versioning enabled for compliance"
  }

  # Test S3 bucket blocks public access
  assert {
    condition     = aws_s3_bucket_public_access_block.main.block_public_acls == true
    error_message = "S3 bucket must block public ACLs"
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.main.block_public_policy == true
    error_message = "S3 bucket must block public policies"
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.main.ignore_public_acls == true
    error_message = "S3 bucket must ignore public ACLs"
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.main.restrict_public_buckets == true
    error_message = "S3 bucket must restrict public bucket policies"
  }
}

# Test: Encryption in transit (SSL/TLS)
run "test_encryption_in_transit" {
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
    project_name = "test-app"
    environment  = "test"
    # ... all other required variables
  }

  # Test security group only allows HTTPS (not HTTP)
  assert {
    condition     = length([for rule in aws_security_group.main.ingress : rule if rule.from_port == 443]) > 0
    error_message = "Security group should allow HTTPS (port 443)"
  }

  assert {
    condition     = length([for rule in aws_security_group.main.ingress : rule if rule.from_port == 80]) == 0 || var.allow_http == true
    error_message = "Security group should not allow HTTP (port 80) unless explicitly enabled"
  }
}

# Test: KMS key usage for sensitive data
run "test_kms_encryption" {
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
    project_name    = "test-app"
    environment     = "test"
    kms_key_id      = "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"
    # ... all other required variables
  }

  # Test S3 bucket uses KMS encryption when key is provided
  assert {
    condition     = var.kms_key_id != "" ? length([for rule in aws_s3_bucket_server_side_encryption_configuration.main.rule : rule if length([for default in rule.apply_server_side_encryption_by_default : default if default.sse_algorithm == "aws:kms"]) > 0]) > 0 : true
    error_message = "S3 bucket should use KMS encryption when KMS key is provided"
  }

  # Test EBS volume uses KMS encryption when key is provided
  assert {
    condition     = var.kms_key_id != "" && length(aws_instance.main) > 0 ? aws_instance.main[0].root_block_device[0].kms_key_id == var.kms_key_id : true
    error_message = "EBS volumes should use specified KMS key when provided"
  }
}

# Test: Resource naming conventions
run "test_naming_conventions" {
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
    project_name = "test-app"
    environment  = "test"
    # ... all other required variables
  }

  # Test VPC follows naming convention: {project_name}-vpc
  assert {
    condition     = can(regex("^[a-z0-9-]+-vpc$", aws_vpc.main.tags["Name"]))
    error_message = "VPC name must follow convention: {project}-vpc (lowercase, alphanumeric, hyphens)"
  }

  # Test S3 bucket name includes environment
  assert {
    condition     = can(regex("^[a-z0-9-]+-${var.environment}-[a-z0-9-]+$", aws_s3_bucket.main.bucket))
    error_message = "S3 bucket name must include environment in the format: {project}-{env}-{purpose}"
  }

  # Test security group name includes project and environment
  assert {
    condition     = can(regex("^${var.project_name}-.+-${var.environment}$", aws_security_group.main.name))
    error_message = "Security group name must include project and environment"
  }
}

# Test: Logging and monitoring enabled
run "test_logging_enabled" {
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
    project_name     = "test-app"
    environment      = "test"
    enable_logging   = true
    # ... all other required variables
  }

  # Test S3 bucket has server access logging (if logging is enabled)
  assert {
    condition     = var.enable_logging ? length(aws_s3_bucket_logging.main) > 0 : true
    error_message = "S3 bucket should have access logging enabled when logging is required"
  }

  # Test VPC flow logs are enabled (if resource exists)
  assert {
    condition     = var.enable_logging ? length(aws_flow_log.vpc) > 0 : true
    error_message = "VPC should have flow logs enabled when logging is required"
  }
}
