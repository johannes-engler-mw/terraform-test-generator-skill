# Integration Tests for Full Infrastructure Deployment
# ⚠️ WARNING: These tests create REAL AWS resources and WILL incur costs!
# These tests use command=apply to test actual resource creation

# Test full infrastructure deployment with EC2 instance
run "test_full_deployment_with_instance" {
  command = apply

  variables {
    aws_region           = "eu-central-1"
    project_name         = "test-tf-gen-skill"
    environment          = "test"
    vpc_cidr             = "10.1.0.0/16"
    public_subnet_count  = 2
    private_subnet_count = 2
    allowed_ingress_ports = [80, 443]
    allowed_cidr_blocks  = ["10.1.0.0/16"]
    common_tags = {
      Environment = "test"
      Project     = "test-tf-gen-skill"
      Owner       = "terraform-test-generator"
    }
    create_instance  = true
    instance_type    = "t3.micro"
    root_volume_size = 30
    kms_key_id       = ""
    ami_id           = ""
  }

  # Verify VPC creation
  assert {
    condition     = aws_vpc.main.id != null
    error_message = "VPC should be created with a valid ID"
  }

  assert {
    condition     = aws_vpc.main.arn != null
    error_message = "VPC should have a valid ARN"
  }

  # Verify subnets creation
  assert {
    condition     = length(aws_subnet.public) == 2
    error_message = "Should create 2 public subnets"
  }

  assert {
    condition     = length(aws_subnet.private) == 2
    error_message = "Should create 2 private subnets"
  }

  assert {
    condition     = aws_subnet.public[0].id != null
    error_message = "Public subnet should have a valid ID"
  }

  # Verify security group creation
  assert {
    condition     = aws_security_group.app.id != null
    error_message = "Security group should be created with a valid ID"
  }

  assert {
    condition     = aws_security_group.app.arn != null
    error_message = "Security group should have a valid ARN"
  }

  # Verify S3 bucket creation
  assert {
    condition     = aws_s3_bucket.app_data.id != null
    error_message = "S3 bucket should be created with a valid ID"
  }

  assert {
    condition     = aws_s3_bucket.app_data.arn != null
    error_message = "S3 bucket should have a valid ARN"
  }

  # Verify KMS key creation
  assert {
    condition     = length(aws_kms_key.s3) == 1
    error_message = "KMS key should be created when kms_key_id is empty"
  }

  assert {
    condition     = aws_kms_key.s3[0].id != null
    error_message = "KMS key should have a valid ID"
  }

  assert {
    condition     = aws_kms_key.s3[0].arn != null
    error_message = "KMS key should have a valid ARN"
  }

  # Verify EC2 instance creation
  assert {
    condition     = length(aws_instance.app) == 1
    error_message = "EC2 instance should be created"
  }

  assert {
    condition     = aws_instance.app[0].id != null
    error_message = "EC2 instance should have a valid ID"
  }

  assert {
    condition     = aws_instance.app[0].arn != null
    error_message = "EC2 instance should have a valid ARN"
  }

  assert {
    condition     = aws_instance.app[0].public_ip != null
    error_message = "EC2 instance should have a public IP"
  }

  # Verify outputs work correctly
  assert {
    condition     = output.vpc_id != null
    error_message = "VPC ID output should be set"
  }

  assert {
    condition     = output.s3_bucket_id != null
    error_message = "S3 bucket ID output should be set"
  }

  assert {
    condition     = output.s3_bucket_arn != null
    error_message = "S3 bucket ARN output should be set"
  }

  assert {
    condition     = output.instance_id != null
    error_message = "Instance ID output should be set when instance is created"
  }
}

# Test infrastructure deployment without EC2 instance
run "test_deployment_without_instance" {
  command = apply

  variables {
    aws_region           = "eu-central-1"
    project_name         = "test-tf-gen-no-ec2"
    environment          = "test"
    vpc_cidr             = "10.2.0.0/16"
    public_subnet_count  = 1
    private_subnet_count = 1
    allowed_ingress_ports = [443]
    allowed_cidr_blocks  = ["10.2.0.0/16"]
    common_tags = {
      Environment = "test"
      Project     = "test-tf-gen-no-ec2"
      Owner       = "terraform-test-generator"
    }
    create_instance  = false
    instance_type    = "t3.micro"
    root_volume_size = 30
    kms_key_id       = ""
    ami_id           = ""
  }

  # Verify basic infrastructure
  assert {
    condition     = aws_vpc.main.id != null
    error_message = "VPC should be created"
  }

  assert {
    condition     = aws_s3_bucket.app_data.id != null
    error_message = "S3 bucket should be created"
  }

  # Verify EC2 instance not created
  assert {
    condition     = length(aws_instance.app) == 0
    error_message = "EC2 instance should not be created when create_instance is false"
  }

  # Verify outputs for non-created instance
  assert {
    condition     = output.instance_id == null
    error_message = "Instance ID output should be null when instance is not created"
  }

  assert {
    condition     = output.instance_public_ip == null
    error_message = "Instance public IP output should be null when instance is not created"
  }
}

# Test infrastructure with custom KMS key
run "test_deployment_with_custom_kms" {
  command = apply

  variables {
    aws_region           = "eu-central-1"
    project_name         = "test-tf-gen-custom-kms"
    environment          = "test"
    vpc_cidr             = "10.3.0.0/16"
    public_subnet_count  = 1
    private_subnet_count = 1
    allowed_ingress_ports = [80]
    allowed_cidr_blocks  = ["10.3.0.0/16"]
    common_tags = {
      Environment = "test"
      Project     = "test-tf-gen-custom-kms"
      Owner       = "terraform-test-generator"
    }
    create_instance  = false
    instance_type    = "t3.micro"
    root_volume_size = 30
    kms_key_id       = "arn:aws:kms:eu-central-1:123456789012:key/12345678-1234-1234-1234-123456789012"
    ami_id           = ""
  }

  # Verify KMS key NOT created when custom key provided
  assert {
    condition     = length(aws_kms_key.s3) == 0
    error_message = "KMS key should not be created when custom kms_key_id is provided"
  }

  # Verify S3 bucket still created
  assert {
    condition     = aws_s3_bucket.app_data.id != null
    error_message = "S3 bucket should be created"
  }
}
