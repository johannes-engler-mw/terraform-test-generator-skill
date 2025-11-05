# Mock Tests for Data Sources
# These tests use override_data to mock external data sources

mock_provider "aws" {
  alias = "mock"
}

# Test with mocked availability zones in different region
run "test_with_us_east_availability_zones" {
  command = plan

  providers = {
    aws = aws.mock
  }

  override_data {
    target = data.aws_availability_zones.available
    values = {
      names    = ["us-east-1a", "us-east-1b", "us-east-1c", "us-east-1d"]
      zone_ids = ["use1-az1", "use1-az2", "use1-az3", "use1-az4"]
    }
  }

  override_data {
    target = data.aws_ami.al2023
    values = {
      id           = "ami-useast123456"
      arn          = "arn:aws:ec2:us-east-1::image/ami-useast123456"
      architecture = "x86_64"
      image_id     = "ami-useast123456"
      name         = "al2023-ami-2024.01.01-kernel-6.1-x86_64"
    }
  }

  variables {
    aws_region           = "us-east-1"
    project_name         = "test-app"
    environment          = "dev"
    vpc_cidr             = "10.0.0.0/16"
    public_subnet_count  = 3
    private_subnet_count = 3
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
    error_message = "Should create 3 public subnets with mocked US East AZs"
  }

  assert {
    condition     = length(aws_subnet.private) == 3
    error_message = "Should create 3 private subnets with mocked US East AZs"
  }
}

# Test with mocked AMI for different architecture scenario
run "test_with_custom_ami_mock" {
  command = plan

  providers = {
    aws = aws.mock
  }

  override_data {
    target = data.aws_availability_zones.available
    values = {
      names    = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
      zone_ids = ["euw1-az1", "euw1-az2", "euw1-az3"]
    }
  }

  override_data {
    target = data.aws_ami.al2023
    values = {
      id           = "ami-arm64test"
      arn          = "arn:aws:ec2:eu-west-1::image/ami-arm64test"
      architecture = "arm64"
      image_id     = "ami-arm64test"
      name         = "al2023-ami-2024.01.01-kernel-6.1-arm64"
    }
  }

  variables {
    aws_region           = "eu-west-1"
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
    create_instance  = true
    instance_type    = "t3.micro"
    root_volume_size = 30
    kms_key_id       = ""
    ami_id           = ""
  }

  assert {
    condition     = length(aws_instance.app) == 1
    error_message = "EC2 instance should be created when create_instance is true"
  }
}

# Test with limited availability zones
run "test_with_limited_availability_zones" {
  command = plan

  providers = {
    aws = aws.mock
  }

  override_data {
    target = data.aws_availability_zones.available
    values = {
      names    = ["ap-south-1a", "ap-south-1b"]
      zone_ids = ["aps1-az1", "aps1-az2"]
    }
  }

  override_data {
    target = data.aws_ami.al2023
    values = {
      id           = "ami-apsouth123"
      arn          = "arn:aws:ec2:ap-south-1::image/ami-apsouth123"
      architecture = "x86_64"
      image_id     = "ami-apsouth123"
      name         = "al2023-ami-minimal-x86_64"
    }
  }

  variables {
    aws_region           = "ap-south-1"
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
    error_message = "Should create subnets based on available AZs"
  }
}
