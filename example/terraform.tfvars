# AWS Configuration
aws_region = "eu-central-1"

# Project Configuration
project_name = "my-app"
environment  = "prod"

# Network Configuration
vpc_cidr             = "10.0.0.0/16"
public_subnet_count  = 2
private_subnet_count = 2

# Security Configuration
allowed_ingress_ports = [80, 443]
allowed_cidr_blocks   = ["10.0.0.0/8"]

# Required Compliance Tags
common_tags = {
  Environment = "prod"
  Project     = "my-app"
  Owner       = "platform-team"
  ManagedBy   = "terraform"
  CostCenter  = "engineering"
}

# EC2 Configuration
create_instance  = true
instance_type    = "t3.micro"
root_volume_size = 30
