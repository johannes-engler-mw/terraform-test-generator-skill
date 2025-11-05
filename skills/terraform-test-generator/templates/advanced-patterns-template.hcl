# Advanced Testing Patterns Template
# File naming: tests/advanced_<feature_name>.tftest.hcl
# Demonstrates advanced testing techniques for complex scenarios

# Define mock provider at file level
mock_provider "aws" {
  alias = "mock"
}

# Pattern 1: Testing set-type attributes with for expressions
# NEVER use [0] indexing on set-type attributes
run "test_set_type_attributes" {
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

  # ✅ CORRECT: Use for expressions to test set-type attributes
  assert {
    condition     = length([for rule in aws_s3_bucket_server_side_encryption_configuration.main.rule : rule if length([for default in rule.apply_server_side_encryption_by_default : default if default.sse_algorithm == "AES256"]) > 0]) > 0
    error_message = "S3 bucket encryption should use AES256"
  }

  # ✅ CORRECT: Test that at least one rule matches criteria
  assert {
    condition     = anytrue([for rule in aws_security_group.main.ingress : rule.from_port == 443])
    error_message = "Security group should allow HTTPS on port 443"
  }

  # ✅ CORRECT: Test that all items match criteria
  assert {
    condition     = alltrue([for subnet in aws_subnet.public : subnet.map_public_ip_on_launch == true])
    error_message = "All public subnets should auto-assign public IPs"
  }
}

# Pattern 2: Testing dynamic blocks
run "test_dynamic_blocks" {
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
    allowed_ingress_ports = [80, 443, 22]
    allowed_cidr_blocks   = ["10.0.0.0/8"]
    # ... all other required variables
  }

  # Test that dynamic ingress rules are created correctly
  assert {
    condition     = length(aws_security_group.main.ingress) == length(var.allowed_ingress_ports)
    error_message = "Security group should have one ingress rule per allowed port"
  }

  # Test all ports are configured
  assert {
    condition     = alltrue([for port in var.allowed_ingress_ports : anytrue([for rule in aws_security_group.main.ingress : rule.from_port == port])])
    error_message = "All specified ports should have corresponding ingress rules"
  }

  # Test CIDR blocks are applied to all rules
  assert {
    condition     = alltrue([for rule in aws_security_group.main.ingress : length(setintersection(toset(rule.cidr_blocks), toset(var.allowed_cidr_blocks))) > 0])
    error_message = "All ingress rules should use allowed CIDR blocks"
  }
}

# Pattern 3: Testing conditional resource creation (count)
run "test_conditional_resources_count" {
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

  override_data {
    target = data.aws_ami.al2023
    values = {
      id           = "ami-test123456"
      architecture = "x86_64"
    }
  }

  variables {
    project_name    = "test-app"
    environment     = "test"
    create_instance = true
    # ... all other required variables
  }

  # Test resource is created when condition is true
  assert {
    condition     = length(aws_instance.main) == 1
    error_message = "EC2 instance should be created when create_instance is true"
  }

  # Test resource configuration when created
  assert {
    condition     = length(aws_instance.main) > 0 ? aws_instance.main[0].instance_type == var.instance_type : true
    error_message = "EC2 instance should use specified instance type when created"
  }
}

# Pattern 4: Testing conditional resource creation (for_each)
run "test_conditional_resources_for_each" {
  command = plan

  providers = {
    aws = aws.mock
  }

  override_data {
    target = data.aws_availability_zones.available
    values = {
      names    = ["us-east-1a", "us-east-1b", "us-east-1c"]
      zone_ids = ["use1-az1", "use1-az2", "use1-az3"]
    }
  }

  variables {
    project_name         = "test-app"
    environment          = "test"
    public_subnet_count  = 3
    private_subnet_count = 2
    vpc_cidr             = "10.0.0.0/16"
    # ... all other required variables
  }

  # Test correct number of subnets created
  assert {
    condition     = length(aws_subnet.public) == var.public_subnet_count
    error_message = "Should create exact number of public subnets specified"
  }

  assert {
    condition     = length(aws_subnet.private) == var.private_subnet_count
    error_message = "Should create exact number of private subnets specified"
  }

  # Test subnet CIDR calculations
  assert {
    condition     = alltrue([for idx, subnet in aws_subnet.public : cidrsubnet(var.vpc_cidr, 8, idx) == subnet.cidr_block])
    error_message = "Public subnet CIDRs should be calculated correctly from VPC CIDR"
  }
}

# Pattern 5: Testing locals and computed values
run "test_locals_computation" {
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
    }
    # ... all other required variables
  }

  # Test that locals merge tags correctly
  assert {
    condition     = contains(keys(aws_vpc.main.tags), "Name") && contains(keys(aws_vpc.main.tags), "Environment") && contains(keys(aws_vpc.main.tags), "Project")
    error_message = "VPC should have merged tags from common_tags and resource-specific tags"
  }

  # Test computed name format
  assert {
    condition     = aws_vpc.main.tags["Name"] == "${var.project_name}-vpc"
    error_message = "VPC name should follow {project_name}-vpc format"
  }
}

# Pattern 6: Testing cross-resource references (configuration only with plan)
run "test_cross_resource_configuration" {
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

  # ✅ CORRECT: Test configuration structure, not computed attributes
  assert {
    condition     = length(aws_subnet.public) > 0
    error_message = "Public subnets should be configured"
  }

  # ✅ CORRECT: Test that resources reference each other in configuration
  assert {
    condition     = length(aws_security_group.main) > 0
    error_message = "Security group should be configured"
  }

  # ❌ WRONG with plan: aws_instance.main[0].vpc_security_group_ids[0]
  # This would fail because it references computed IDs from security group
  # Use integration test with apply for this instead
}

# Pattern 7: Testing complex ternary and conditional logic
run "test_conditional_logic" {
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
    kms_key_id   = ""  # Empty - should create KMS key
    # ... all other required variables
  }

  # Test conditional KMS key creation logic
  assert {
    condition     = var.kms_key_id == "" ? length(aws_kms_key.main) == 1 : length(aws_kms_key.main) == 0
    error_message = "Should create KMS key only when kms_key_id is not provided"
  }
}

# Pattern 8: Testing with multiple data source mocks
run "test_multiple_data_sources" {
  command = plan

  providers = {
    aws = aws.mock
  }

  # Mock availability zones data source
  override_data {
    target = data.aws_availability_zones.available
    values = {
      names    = ["us-east-1a", "us-east-1b", "us-east-1c"]
      zone_ids = ["use1-az1", "use1-az2", "use1-az3"]
    }
  }

  # Mock AMI data source
  override_data {
    target = data.aws_ami.al2023
    values = {
      id           = "ami-0123456789abcdef0"
      arn          = "arn:aws:ec2:us-east-1::image/ami-0123456789abcdef0"
      architecture = "x86_64"
      image_id     = "ami-0123456789abcdef0"
      name         = "al2023-ami-2023.3.20240101.0-kernel-6.1-x86_64"
    }
  }

  # Mock caller identity data source (if used for tagging)
  override_data {
    target = data.aws_caller_identity.current
    values = {
      account_id = "123456789012"
      arn        = "arn:aws:iam::123456789012:root"
      user_id    = "AIDACKCEVSQ6C2EXAMPLE"
    }
  }

  variables {
    project_name    = "test-app"
    environment     = "test"
    create_instance = true
    ami_id          = ""  # Should use data source
    # ... all other required variables
  }

  # Test AMI is used when ami_id is empty
  assert {
    condition     = length(aws_instance.main) > 0
    error_message = "EC2 instance should be configured when create_instance is true"
  }
}

# Pattern 9: Testing error conditions (expect_failures with preconditions)
run "test_precondition_failure" {
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

  override_data {
    target = data.aws_ami.al2023
    values = {
      id           = "ami-test123456"
      architecture = "x86_64"
    }
  }

  variables {
    project_name    = "test-app"
    environment     = "prod"  # prod with t2.micro should fail precondition
    create_instance = true
    instance_type   = "t2.micro"
    # ... all other required variables
  }

  # Expect precondition to fail (if module has precondition: prod cannot use t2.micro)
  expect_failures = [aws_instance.main]
}

# Pattern 10: Testing output calculations and dependencies
run "test_output_logic" {
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
    project_name         = "test-app"
    environment          = "test"
    public_subnet_count  = 2
    private_subnet_count = 3
    # ... all other required variables
  }

  # Test output structure and logic (not computed values)
  assert {
    condition     = length(output.public_subnet_ids) == var.public_subnet_count
    error_message = "Output public_subnet_ids should have correct length"
  }

  assert {
    condition     = length(output.private_subnet_ids) == var.private_subnet_count
    error_message = "Output private_subnet_ids should have correct length"
  }
}
