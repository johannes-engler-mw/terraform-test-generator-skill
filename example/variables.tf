variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]{1}$", var.aws_region))
    error_message = "AWS region must be in the format: xx-xxxx-x (e.g., us-east-1)"
  }
}

variable "project_name" {
  description = "Name of the project"
  type        = string

  validation {
    condition     = length(var.project_name) > 0 && length(var.project_name) <= 30
    error_message = "Project name must be between 1 and 30 characters"
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod"
  }
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block"
  }
}

variable "public_subnet_count" {
  description = "Number of public subnets to create"
  type        = number
  default     = 2

  validation {
    condition     = var.public_subnet_count >= 1 && var.public_subnet_count <= 3
    error_message = "Public subnet count must be between 1 and 3"
  }
}

variable "private_subnet_count" {
  description = "Number of private subnets to create"
  type        = number
  default     = 2

  validation {
    condition     = var.private_subnet_count >= 1 && var.private_subnet_count <= 3
    error_message = "Private subnet count must be between 1 and 3"
  }
}

variable "allowed_ingress_ports" {
  description = "List of allowed ingress ports"
  type        = list(number)
  default     = [80, 443]

  validation {
    condition     = alltrue([for port in var.allowed_ingress_ports : port > 0 && port <= 65535])
    error_message = "All ports must be between 1 and 65535"
  }
}

variable "allowed_cidr_blocks" {
  description = "List of CIDR blocks allowed to access the application"
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.allowed_cidr_blocks) > 0
    error_message = "At least one CIDR block must be specified for security"
  }

  validation {
    condition     = !contains(var.allowed_cidr_blocks, "0.0.0.0/0")
    error_message = "Unrestricted access (0.0.0.0/0) is not allowed for security compliance"
  }
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)

  validation {
    condition = alltrue([
      contains(keys(var.common_tags), "Environment"),
      contains(keys(var.common_tags), "Project"),
      contains(keys(var.common_tags), "Owner")
    ])
    error_message = "Common tags must include Environment, Project, and Owner"
  }
}

variable "kms_key_id" {
  description = "Optional KMS key ARN for S3 bucket encryption. If empty, a key is created."
  type        = string
  default     = ""

  validation {
    condition     = var.kms_key_id == "" || can(regex("^arn:aws:kms:[a-z0-9-]+:[0-9]{12}:key/.+", var.kms_key_id))
    error_message = "kms_key_id must be empty or a valid KMS key ARN"
  }
}

variable "create_instance" {
  description = "Whether to create EC2 instance"
  type        = bool
  default     = false
}

variable "ami_id" {
  description = "Optional AMI ID for EC2 instance. If empty, a recent Amazon Linux 2023 (x86_64) AMI is selected."
  type        = string
  default     = ""

  validation {
    condition     = var.ami_id == "" || can(regex("^ami-[0-9a-f]+$", var.ami_id))
    error_message = "ami_id must be empty or a valid AMI ID (ami-xxxxxxxx)"
  }
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"

  validation {
    condition     = can(regex("^t[2-3]\\.(micro|small|medium|large)$", var.instance_type))
    error_message = "Instance type must be a valid t2 or t3 instance type"
  }
}

variable "root_volume_size" {
  description = "Size of root volume in GB"
  type        = number
  default     = 30

  validation {
    condition     = var.root_volume_size >= 8 && var.root_volume_size <= 100
    error_message = "Root volume size must be between 8 and 100 GB"
  }
}
