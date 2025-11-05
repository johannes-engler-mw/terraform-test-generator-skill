# Unit Tests for Security Group Configuration
# These tests use mock providers and command=plan to test security group logic

mock_provider "aws" {
  alias = "mock"
}

# Test security group basic configuration
run "test_security_group_configuration" {
  command = plan

  providers = {
    aws = aws.mock
  }

  override_data {
    target = data.aws_availability_zones.available
    values = {
      names    = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
      zone_ids = ["euc1-az1", "euc1-az2", "euc1-az3"]
    }
  }

  override_data {
    target = data.aws_ami.al2023
    values = {
      id           = "ami-test123456"
      arn          = "arn:aws:ec2:eu-central-1::image/ami-test123456"
      architecture = "x86_64"
      image_id     = "ami-test123456"
      name         = "al2023-ami-test-x86_64"
    }
  }

  variables {
    aws_region           = "eu-central-1"
    project_name         = "test-app"
    environment          = "dev"
    vpc_cidr             = "10.0.0.0/16"
    public_subnet_count  = 2
    private_subnet_count = 2
    allowed_ingress_ports = [80, 443]
    allowed_cidr_blocks  = ["10.0.0.0/8"]
    common_tags = {
      Environment = "dev"
      Project     = "test-app"
      Owner       = "test-team"
    }
    create_instance  = false
    instance_type    = "t3.micro"
    root_volume_size = 30
    kms_key_id       = ""
    ami_id           = ""
  }

  assert {
    condition     = aws_security_group.app.name == "test-app-app-sg"
    error_message = "Security group should have correct name"
  }

  assert {
    condition     = aws_security_group.app.description == "Security group for application"
    error_message = "Security group should have correct description"
  }

  assert {
    condition     = aws_security_group.app.tags["Name"] == "test-app-app-sg"
    error_message = "Security group should have correct Name tag"
  }
}

# Test security group ingress rules with dynamic blocks
run "test_security_group_ingress_ports" {
  command = plan

  providers = {
    aws = aws.mock
  }

  override_data {
    target = data.aws_availability_zones.available
    values = {
      names    = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
      zone_ids = ["euc1-az1", "euc1-az2", "euc1-az3"]
    }
  }

  override_data {
    target = data.aws_ami.al2023
    values = {
      id           = "ami-test123456"
      arn          = "arn:aws:ec2:eu-central-1::image/ami-test123456"
      architecture = "x86_64"
      image_id     = "ami-test123456"
      name         = "al2023-ami-test-x86_64"
    }
  }

  variables {
    aws_region           = "eu-central-1"
    project_name         = "test-app"
    environment          = "dev"
    vpc_cidr             = "10.0.0.0/16"
    public_subnet_count  = 2
    private_subnet_count = 2
    allowed_ingress_ports = [80, 443, 8080]
    allowed_cidr_blocks  = ["10.0.0.0/8"]
    common_tags = {
      Environment = "dev"
      Project     = "test-app"
      Owner       = "test-team"
    }
    create_instance  = false
    instance_type    = "t3.micro"
    root_volume_size = 30
    kms_key_id       = ""
    ami_id           = ""
  }

  assert {
    condition     = length(aws_security_group.app.ingress) == 3
    error_message = "Security group should have 3 ingress rules"
  }
}

# Test security group with custom ports
run "test_security_group_custom_ports" {
  command = plan

  providers = {
    aws = aws.mock
  }

  override_data {
    target = data.aws_availability_zones.available
    values = {
      names    = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
      zone_ids = ["euc1-az1", "euc1-az2", "euc1-az3"]
    }
  }

  override_data {
    target = data.aws_ami.al2023
    values = {
      id           = "ami-test123456"
      arn          = "arn:aws:ec2:eu-central-1::image/ami-test123456"
      architecture = "x86_64"
      image_id     = "ami-test123456"
      name         = "al2023-ami-test-x86_64"
    }
  }

  variables {
    aws_region           = "eu-central-1"
    project_name         = "test-app"
    environment          = "dev"
    vpc_cidr             = "10.0.0.0/16"
    public_subnet_count  = 2
    private_subnet_count = 2
    allowed_ingress_ports = [22]
    allowed_cidr_blocks  = ["10.0.0.0/8"]
    common_tags = {
      Environment = "dev"
      Project     = "test-app"
      Owner       = "test-team"
    }
    create_instance  = false
    instance_type    = "t3.micro"
    root_volume_size = 30
    kms_key_id       = ""
    ami_id           = ""
  }

  assert {
    condition     = length(aws_security_group.app.ingress) == 1
    error_message = "Security group should have 1 ingress rule for SSH"
  }
}

# Test security group egress rules
run "test_security_group_egress" {
  command = plan

  providers = {
    aws = aws.mock
  }

  override_data {
    target = data.aws_availability_zones.available
    values = {
      names    = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
      zone_ids = ["euc1-az1", "euc1-az2", "euc1-az3"]
    }
  }

  override_data {
    target = data.aws_ami.al2023
    values = {
      id           = "ami-test123456"
      arn          = "arn:aws:ec2:eu-central-1::image/ami-test123456"
      architecture = "x86_64"
      image_id     = "ami-test123456"
      name         = "al2023-ami-test-x86_64"
    }
  }

  variables {
    aws_region           = "eu-central-1"
    project_name         = "test-app"
    environment          = "dev"
    vpc_cidr             = "10.0.0.0/16"
    public_subnet_count  = 2
    private_subnet_count = 2
    allowed_ingress_ports = [80, 443]
    allowed_cidr_blocks  = ["10.0.0.0/8"]
    common_tags = {
      Environment = "dev"
      Project     = "test-app"
      Owner       = "test-team"
    }
    create_instance  = false
    instance_type    = "t3.micro"
    root_volume_size = 30
    kms_key_id       = ""
    ami_id           = ""
  }

  assert {
    condition     = length(aws_security_group.app.egress) == 1
    error_message = "Security group should have 1 egress rule"
  }

  assert {
    condition     = length([for rule in aws_security_group.app.egress : rule if rule.from_port == 0]) > 0
    error_message = "Egress rule should allow all ports (from_port = 0)"
  }

  assert {
    condition     = length([for rule in aws_security_group.app.egress : rule if rule.protocol == "-1"]) > 0
    error_message = "Egress rule should allow all protocols"
  }
}
