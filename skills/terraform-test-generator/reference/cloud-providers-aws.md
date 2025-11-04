# AWS Provider Patterns

## AWS Mock Provider

```hcl
mock_provider "aws" {
  alias = "mock"
}

# With resource mocks
mock_provider "aws" {
  alias = "mock"

  mock_resource "aws_s3_bucket" {
    defaults = {
      id                    = "test-bucket"
      bucket                = "test-bucket"
      arn                   = "arn:aws:s3:::test-bucket"
      region                = "us-east-1"
      bucket_domain_name    = "test-bucket.s3.amazonaws.com"
    }
  }

  mock_resource "aws_instance" {
    defaults = {
      id                    = "i-1234567890abcdef0"
      arn                   = "arn:aws:ec2:us-east-1:123456789012:instance/i-1234567890abcdef0"
      instance_type         = "t3.micro"
      availability_zone     = "us-east-1a"
    }
  }

  mock_resource "aws_lambda_function" {
    defaults = {
      id                     = "test-lambda-function"
      arn                    = "arn:aws:lambda:us-east-1:123456789012:function:test-lambda-function"
      function_name          = "test-lambda-function"
      runtime                = "python3.11"
      handler                = "index.handler"
      invoke_arn             = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:123456789012:function:test-lambda-function/invocations"
    }
  }

  mock_resource "aws_db_instance" {
    defaults = {
      id                     = "test-db-instance"
      arn                    = "arn:aws:rds:us-east-1:123456789012:db:test-db-instance"
      engine                 = "postgres"
      engine_version         = "15.3"
      instance_class         = "db.t3.micro"
      endpoint               = "test-db-instance.abcdef.us-east-1.rds.amazonaws.com:5432"
      address                = "test-db-instance.abcdef.us-east-1.rds.amazonaws.com"
    }
  }

  mock_resource "aws_ecs_cluster" {
    defaults = {
      id                     = "arn:aws:ecs:us-east-1:123456789012:cluster/test-cluster"
      arn                    = "arn:aws:ecs:us-east-1:123456789012:cluster/test-cluster"
      name                   = "test-cluster"
    }
  }

  mock_resource "aws_eks_cluster" {
    defaults = {
      id                     = "test-eks-cluster"
      arn                    = "arn:aws:eks:us-east-1:123456789012:cluster/test-eks-cluster"
      name                   = "test-eks-cluster"
      endpoint               = "https://ABC123.gr7.us-east-1.eks.amazonaws.com"
      version                = "1.28"
    }
  }
}
```

## AWS Set-Type Attributes

**CRITICAL:** AWS security groups, route tables, and other resources use set-type collections. NEVER index with `[0]`.

**Incorrect:**
```hcl
# ❌ WRONG - Will fail with set-type error
assert {
  condition = aws_security_group.main.ingress[0].from_port == 443
  error_message = "Should allow HTTPS"
}
```

**Correct:**
```hcl
# ✅ CORRECT - Use for expression
assert {
  condition = length([for rule in aws_security_group.main.ingress : rule if rule.from_port == 443]) > 0
  error_message = "Should allow HTTPS"
}
```

## AWS Data Source Mocking

```hcl
# Mock availability zones
override_data {
  target = data.aws_availability_zones.available
  values = {
    names = ["us-east-1a", "us-east-1b", "us-east-1c"]
    zone_ids = ["use1-az1", "use1-az2", "use1-az3"]
  }
}

# Mock caller identity
override_data {
  target = data.aws_caller_identity.current
  values = {
    account_id = "123456789012"
    arn        = "arn:aws:iam::123456789012:root"
    user_id    = "AIDAI1234567890EXAMPLE"
  }
}

# Mock region
override_data {
  target = data.aws_region.current
  values = {
    name        = "us-east-1"
    endpoint    = "ec2.us-east-1.amazonaws.com"
    description = "US East (N. Virginia)"
  }
}

# Mock VPC
override_data {
  target = data.aws_vpc.main
  values = {
    id         = "vpc-12345678"
    cidr_block = "10.0.0.0/16"
    arn        = "arn:aws:ec2:us-east-1:123456789012:vpc/vpc-12345678"
  }
}

# Mock AMI
override_data {
  target = data.aws_ami.ubuntu
  values = {
    id               = "ami-12345678"
    arn              = "arn:aws:ec2:us-east-1::image/ami-12345678"
    architecture     = "x86_64"
    image_id         = "ami-12345678"
    name             = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-20231201"
  }
}
```

## AWS Computed Attributes

### Attributes to AVOID with `command = plan`
- `.id` - Resource ID
- `.arn` - Amazon Resource Name
- `.dns_name` - DNS endpoints
- `.endpoint` - Service endpoints
- `.hosted_zone_id` - Route53 zone IDs
- Any attribute referencing another resource's computed value

### What You CAN Test with `command = plan`
- ✅ Variables: `var.region`
- ✅ Locals: `local.computed_value`
- ✅ Configuration structure: `length(resource.rule)`
- ✅ Static values: `resource.tags["Name"]`
- ✅ Conditional counts: `length(resource)` tests if resource exists

## AWS Security Tests

```hcl
# KMS encryption for S3
assert {
  condition = length([for rule in aws_s3_bucket_server_side_encryption_configuration.main.rule : rule if length([for default in rule.apply_server_side_encryption_by_default : default if default.sse_algorithm == "aws:kms"]) > 0]) > 0
  error_message = "S3 bucket must use KMS encryption"
}

# Security group restrictive rules
assert {
  condition = length([for rule in aws_security_group.main.ingress : rule if rule.cidr_blocks[0] == "0.0.0.0/0"]) == 0
  error_message = "Security groups must not allow unrestricted access"
}

# S3 public access block
assert {
  condition = aws_s3_bucket_public_access_block.main.block_public_acls == true
  error_message = "S3 bucket must block public ACLs"
}
```

## AWS Tagging

```hcl
assert {
  condition = alltrue([
    contains(keys(aws_instance.main.tags), "Environment"),
    contains(keys(aws_instance.main.tags), "Project"),
    contains(keys(aws_instance.main.tags), "Owner")
  ])
  error_message = "Resource must have Environment, Project, and Owner tags"
}
```

## AWS Naming Conventions

```hcl
assert {
  condition = can(regex("^[a-z0-9-]+$", var.resource_name))
  error_message = "AWS resource names should use lowercase letters, numbers, and hyphens"
}
```
