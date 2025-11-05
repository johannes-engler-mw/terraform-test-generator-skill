# Unit Tests for Networking Resources (VPC, Subnets)
# These tests use mock providers and command=plan to test configuration logic

mock_provider "aws" {
  alias = "mock"
}

# Test VPC configuration
run "test_vpc_configuration" {
  command = plan

  providers = {
    aws = aws.mock
  }

  # Mock data sources
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
    condition     = aws_vpc.main.cidr_block == "10.0.0.0/16"
    error_message = "VPC CIDR block should match the input variable"
  }

  assert {
    condition     = aws_vpc.main.enable_dns_hostnames == true
    error_message = "VPC should have DNS hostnames enabled"
  }

  assert {
    condition     = aws_vpc.main.enable_dns_support == true
    error_message = "VPC should have DNS support enabled"
  }

  assert {
    condition     = aws_vpc.main.tags["Name"] == "test-app-vpc"
    error_message = "VPC should have correct Name tag"
  }
}

# Test public subnet configuration
run "test_public_subnets" {
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
    condition     = length(aws_subnet.public) == 2
    error_message = "Should create 2 public subnets"
  }

  assert {
    condition     = aws_subnet.public[0].map_public_ip_on_launch == true
    error_message = "Public subnets should auto-assign public IPs"
  }

  assert {
    condition     = aws_subnet.public[0].tags["Type"] == "public"
    error_message = "Public subnets should have Type tag set to public"
  }

  assert {
    condition     = aws_subnet.public[0].cidr_block == "10.0.0.0/24"
    error_message = "First public subnet CIDR should be correctly calculated"
  }
}

# Test private subnet configuration
run "test_private_subnets" {
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
    condition     = length(aws_subnet.private) == 2
    error_message = "Should create 2 private subnets"
  }

  assert {
    condition     = aws_subnet.private[0].map_public_ip_on_launch == false
    error_message = "Private subnets should not auto-assign public IPs"
  }

  assert {
    condition     = aws_subnet.private[0].tags["Type"] == "private"
    error_message = "Private subnets should have Type tag set to private"
  }

  assert {
    condition     = aws_subnet.private[0].cidr_block == "10.0.100.0/24"
    error_message = "First private subnet CIDR should be correctly calculated with offset"
  }
}

# Test subnet count variation
run "test_subnet_count_variation" {
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
    public_subnet_count  = 3
    private_subnet_count = 1
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
    condition     = length(aws_subnet.public) == 3
    error_message = "Should create 3 public subnets when count is 3"
  }

  assert {
    condition     = length(aws_subnet.private) == 1
    error_message = "Should create 1 private subnet when count is 1"
  }
}
