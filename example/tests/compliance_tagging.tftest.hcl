# Compliance Tests for Tagging Requirements
# These tests verify that all resources have required tags

mock_provider "aws" {
  alias = "mock"
}

# Test VPC tagging compliance
run "test_vpc_tagging_compliance" {
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

  # Verify VPC has required tags
  assert {
    condition     = alltrue([contains(keys(aws_vpc.main.tags), "Environment"), contains(keys(aws_vpc.main.tags), "Project"), contains(keys(aws_vpc.main.tags), "Owner")])
    error_message = "VPC must have Environment, Project, and Owner tags"
  }

  assert {
    condition     = contains(keys(aws_vpc.main.tags), "Name")
    error_message = "VPC must have a Name tag"
  }
}

# Test subnet tagging compliance
run "test_subnet_tagging_compliance" {
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

  # Verify public subnets have required tags
  assert {
    condition     = alltrue([for subnet in aws_subnet.public : alltrue([contains(keys(subnet.tags), "Environment"), contains(keys(subnet.tags), "Project"), contains(keys(subnet.tags), "Owner")])])
    error_message = "All public subnets must have Environment, Project, and Owner tags"
  }

  assert {
    condition     = alltrue([for subnet in aws_subnet.public : contains(keys(subnet.tags), "Name")])
    error_message = "All public subnets must have a Name tag"
  }

  assert {
    condition     = alltrue([for subnet in aws_subnet.public : contains(keys(subnet.tags), "Type")])
    error_message = "All public subnets must have a Type tag"
  }

  # Verify private subnets have required tags
  assert {
    condition     = alltrue([for subnet in aws_subnet.private : alltrue([contains(keys(subnet.tags), "Environment"), contains(keys(subnet.tags), "Project"), contains(keys(subnet.tags), "Owner")])])
    error_message = "All private subnets must have Environment, Project, and Owner tags"
  }

  assert {
    condition     = alltrue([for subnet in aws_subnet.private : contains(keys(subnet.tags), "Type")])
    error_message = "All private subnets must have a Type tag"
  }
}

# Test security group tagging compliance
run "test_security_group_tagging_compliance" {
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

  # Verify security group has required tags
  assert {
    condition     = alltrue([contains(keys(aws_security_group.app.tags), "Environment"), contains(keys(aws_security_group.app.tags), "Project"), contains(keys(aws_security_group.app.tags), "Owner")])
    error_message = "Security group must have Environment, Project, and Owner tags"
  }

  assert {
    condition     = contains(keys(aws_security_group.app.tags), "Name")
    error_message = "Security group must have a Name tag"
  }
}

# Test S3 bucket tagging compliance
run "test_s3_bucket_tagging_compliance" {
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

  # Verify S3 bucket has required tags
  assert {
    condition     = alltrue([contains(keys(aws_s3_bucket.app_data.tags), "Environment"), contains(keys(aws_s3_bucket.app_data.tags), "Project"), contains(keys(aws_s3_bucket.app_data.tags), "Owner")])
    error_message = "S3 bucket must have Environment, Project, and Owner tags"
  }

  assert {
    condition     = contains(keys(aws_s3_bucket.app_data.tags), "Name")
    error_message = "S3 bucket must have a Name tag"
  }
}

# Test EC2 instance tagging compliance (when created)
run "test_ec2_instance_tagging_compliance" {
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

  # Verify EC2 instance has required tags (when created)
  assert {
    condition     = length(aws_instance.app) == 0 || alltrue([contains(keys(aws_instance.app[0].tags), "Environment"), contains(keys(aws_instance.app[0].tags), "Project"), contains(keys(aws_instance.app[0].tags), "Owner")])
    error_message = "EC2 instance must have Environment, Project, and Owner tags"
  }

  assert {
    condition     = length(aws_instance.app) == 0 || contains(keys(aws_instance.app[0].tags), "Name")
    error_message = "EC2 instance must have a Name tag"
  }
}
