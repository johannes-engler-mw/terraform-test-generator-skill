# Unit Tests for EC2 Instance Configuration
# These tests use mock providers and command=plan to test compute resources

mock_provider "aws" {
  alias = "mock"
}

# Test EC2 instance creation when enabled
run "test_ec2_instance_creation_enabled" {
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

  assert {
    condition     = aws_instance.app[0].instance_type == "t3.micro"
    error_message = "EC2 instance should use correct instance type"
  }

  assert {
    condition     = aws_instance.app[0].tags["Name"] == "test-app-app-instance"
    error_message = "EC2 instance should have correct Name tag"
  }
}

# Test EC2 instance not created when disabled
run "test_ec2_instance_creation_disabled" {
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
    condition     = length(aws_instance.app) == 0
    error_message = "EC2 instance should not be created when create_instance is false"
  }
}

# Test EC2 instance with custom AMI
run "test_ec2_instance_custom_ami" {
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
    create_instance  = true
    instance_type    = "t3.micro"
    root_volume_size = 30
    kms_key_id       = ""
    ami_id           = "ami-0a1b2c3d4e5f6789"
  }

  assert {
    condition     = aws_instance.app[0].ami == "ami-0a1b2c3d4e5f6789"
    error_message = "EC2 instance should use custom AMI when provided"
  }
}

# Test EC2 instance root volume encryption
run "test_ec2_instance_encryption" {
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
    create_instance  = true
    instance_type    = "t3.micro"
    root_volume_size = 50
    kms_key_id       = ""
    ami_id           = ""
  }

  assert {
    condition     = aws_instance.app[0].root_block_device[0].encrypted == true
    error_message = "EC2 instance root volume must be encrypted"
  }

  assert {
    condition     = aws_instance.app[0].root_block_device[0].volume_size == 50
    error_message = "EC2 instance root volume should have correct size"
  }
}

# Test EC2 instance with different instance types
run "test_ec2_instance_type_variation" {
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
    create_instance  = true
    instance_type    = "t3.small"
    root_volume_size = 30
    kms_key_id       = ""
    ami_id           = ""
  }

  assert {
    condition     = aws_instance.app[0].instance_type == "t3.small"
    error_message = "EC2 instance should support different instance types"
  }
}
