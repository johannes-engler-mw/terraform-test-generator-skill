# Validation Tests for Resource Preconditions
# These tests verify lifecycle precondition rules

mock_provider "aws" {
  alias = "mock"
}

# Test t2.micro instance type NOT allowed in non-dev environment (should fail)
run "test_t2_micro_not_allowed_in_prod" {
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
      arn          = "arn:aws:ec2:us-east-1::image/ami-test123456"
      architecture = "x86_64"
      image_id     = "ami-test123456"
      name         = "al2023-ami-test-x86_64"
    }
  }

  variables {
    aws_region           = "us-east-1"
    project_name         = "test-app"
    environment          = "prod"
    vpc_cidr             = "10.0.0.0/16"
    public_subnet_count  = 2
    private_subnet_count = 2
    allowed_ingress_ports = [80, 443]
    allowed_cidr_blocks  = ["10.0.0.0/8"]
    common_tags = {
      Environment = "prod"
      Project     = "test-app"
      Owner       = "test-team"
    }
    create_instance  = true
    instance_type    = "t2.micro"
    root_volume_size = 30
    kms_key_id       = ""
    ami_id           = ""
  }

  expect_failures = [aws_instance.app[0]]
}

# Test t2.micro instance type IS allowed in dev environment (should pass)
run "test_t2_micro_allowed_in_dev" {
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
      arn          = "arn:aws:ec2:us-east-1::image/ami-test123456"
      architecture = "x86_64"
      image_id     = "ami-test123456"
      name         = "al2023-ami-test-x86_64"
    }
  }

  variables {
    aws_region           = "us-east-1"
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
    instance_type    = "t2.micro"
    root_volume_size = 30
    kms_key_id       = ""
    ami_id           = ""
  }

  assert {
    condition     = length(aws_instance.app) == 1
    error_message = "EC2 instance with t2.micro should be created in dev environment"
  }
}

# Test t2.micro NOT allowed in staging environment (should fail)
run "test_t2_micro_not_allowed_in_staging" {
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
      arn          = "arn:aws:ec2:us-east-1::image/ami-test123456"
      architecture = "x86_64"
      image_id     = "ami-test123456"
      name         = "al2023-ami-test-x86_64"
    }
  }

  variables {
    aws_region           = "us-east-1"
    project_name         = "test-app"
    environment          = "staging"
    vpc_cidr             = "10.0.0.0/16"
    public_subnet_count  = 2
    private_subnet_count = 2
    allowed_ingress_ports = [80, 443]
    allowed_cidr_blocks  = ["10.0.0.0/8"]
    common_tags = {
      Environment = "staging"
      Project     = "test-app"
      Owner       = "test-team"
    }
    create_instance  = true
    instance_type    = "t2.micro"
    root_volume_size = 30
    kms_key_id       = ""
    ami_id           = ""
  }

  expect_failures = [aws_instance.app[0]]
}

# Test t3.micro IS allowed in prod (should pass)
run "test_t3_micro_allowed_in_prod" {
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
      arn          = "arn:aws:ec2:us-east-1::image/ami-test123456"
      architecture = "x86_64"
      image_id     = "ami-test123456"
      name         = "al2023-ami-test-x86_64"
    }
  }

  variables {
    aws_region           = "us-east-1"
    project_name         = "test-app"
    environment          = "prod"
    vpc_cidr             = "10.0.0.0/16"
    public_subnet_count  = 2
    private_subnet_count = 2
    allowed_ingress_ports = [80, 443]
    allowed_cidr_blocks  = ["10.0.0.0/8"]
    common_tags = {
      Environment = "prod"
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
    error_message = "EC2 instance with t3.micro should be created in prod environment"
  }
}
