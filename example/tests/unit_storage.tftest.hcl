# Unit Tests for S3 Bucket and KMS Configuration
# These tests use mock providers and command=plan to test storage configuration

mock_provider "aws" {
  alias = "mock"
}

# Test S3 bucket configuration
run "test_s3_bucket_configuration" {
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
    condition     = aws_s3_bucket.app_data.bucket == "test-app-app-data-dev-42"
    error_message = "S3 bucket should have correct name format"
  }

  assert {
    condition     = aws_s3_bucket.app_data.tags["Name"] == "test-app-app-data"
    error_message = "S3 bucket should have correct Name tag"
  }

  assert {
    condition     = contains(keys(aws_s3_bucket.app_data.tags), "Environment")
    error_message = "S3 bucket should have Environment tag"
  }
}

# Test S3 bucket versioning
run "test_s3_bucket_versioning" {
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
    condition     = aws_s3_bucket_versioning.app_data.versioning_configuration[0].status == "Enabled"
    error_message = "S3 bucket versioning should be enabled"
  }
}

# Test S3 bucket encryption configuration
run "test_s3_bucket_encryption" {
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
    condition     = length([for rule in aws_s3_bucket_server_side_encryption_configuration.app_data.rule : rule if length([for default in rule.apply_server_side_encryption_by_default : default if default.sse_algorithm == "aws:kms"]) > 0]) > 0
    error_message = "S3 bucket must use KMS encryption"
  }
}

# Test S3 bucket public access block
run "test_s3_bucket_public_access_block" {
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
    condition     = aws_s3_bucket_public_access_block.app_data.block_public_acls == true
    error_message = "S3 bucket must block public ACLs"
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.app_data.block_public_policy == true
    error_message = "S3 bucket must block public policy"
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.app_data.ignore_public_acls == true
    error_message = "S3 bucket must ignore public ACLs"
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.app_data.restrict_public_buckets == true
    error_message = "S3 bucket must restrict public buckets"
  }
}

# Test KMS key creation when no key provided
run "test_kms_key_creation" {
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
    condition     = length(aws_kms_key.s3) == 1
    error_message = "KMS key should be created when kms_key_id is empty"
  }

  assert {
    condition     = aws_kms_key.s3[0].enable_key_rotation == true
    error_message = "KMS key should have rotation enabled"
  }

  assert {
    condition     = aws_kms_key.s3[0].description == "S3 encryption key for test-app-dev"
    error_message = "KMS key should have correct description"
  }
}

# Test KMS key not created when key provided
run "test_no_kms_key_when_provided" {
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
    kms_key_id       = "arn:aws:kms:eu-central-1:123456789012:key/12345678-1234-1234-1234-123456789012"
    ami_id           = ""
  }

  assert {
    condition     = length(aws_kms_key.s3) == 0
    error_message = "KMS key should not be created when kms_key_id is provided"
  }
}
