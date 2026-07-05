# AWS Provider Patterns

This file covers AWS-specific quirks. For shared rules (mock-provider basics, `[0]` on sets, computed attributes under `plan`, single-line conditions, generic security/tagging assertions), see [anti-patterns.md](anti-patterns.md) and [compliance-patterns.md](compliance-patterns.md).

## Mock provider with resource defaults

For resources whose attributes you reference in assertions, supply sensible defaults so plan-mode tests have realistic values:

```hcl
mock_provider "aws" {
  alias = "mock"

  mock_resource "aws_s3_bucket" {
    defaults = {
      id                 = "test-bucket"
      bucket             = "test-bucket"
      arn                = "arn:aws:s3:::test-bucket"
      region             = "us-east-1"
      bucket_domain_name = "test-bucket.s3.amazonaws.com"
    }
  }

  mock_resource "aws_instance" {
    defaults = {
      id                = "i-1234567890abcdef0"
      arn               = "arn:aws:ec2:us-east-1:123456789012:instance/i-1234567890abcdef0"
      instance_type     = "t3.micro"
      availability_zone = "us-east-1a"
    }
  }

  mock_resource "aws_db_instance" {
    defaults = {
      id             = "test-db-instance"
      arn            = "arn:aws:rds:us-east-1:123456789012:db:test-db-instance"
      engine         = "postgres"
      engine_version = "15.3"
      endpoint       = "test-db-instance.abcdef.us-east-1.rds.amazonaws.com:5432"
    }
  }
}
```

ARNs follow `arn:aws:<service>:<region>:<account>:<type>/<id>`. Use `123456789012` as a synthetic account ID and `us-east-1` as a synthetic region — both are unambiguously not-real test values.

## Data source mocking

Most AWS modules reach for one of these data sources. Drop these into `override_data` blocks per run, or as `mock_data` blocks at file level if every scenario uses the same values:

```hcl
override_data {
  target = data.aws_availability_zones.available
  values = {
    names    = ["us-east-1a", "us-east-1b", "us-east-1c"]
    zone_ids = ["use1-az1", "use1-az2", "use1-az3"]
  }
}

override_data {
  target = data.aws_caller_identity.current
  values = {
    account_id = "123456789012"
    arn        = "arn:aws:iam::123456789012:root"
    user_id    = "AIDAI1234567890EXAMPLE"
  }
}

override_data {
  target = data.aws_region.current
  values = {
    name        = "us-east-1"
    endpoint    = "ec2.us-east-1.amazonaws.com"
    description = "US East (N. Virginia)"
  }
}

override_data {
  target = data.aws_ami.ubuntu  # or any AMI lookup
  values = {
    id           = "ami-12345678"
    arn          = "arn:aws:ec2:us-east-1::image/ami-12345678"
    architecture = "x86_64"
    name         = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-20231201"
  }
}
```

## Naming-convention quirks

S3 bucket names are **globally unique** across all AWS accounts. Generated integration-test bucket names must include a unique suffix (random ID) to avoid collisions with real buckets.

```hcl
# ✅ Avoids collision with any real bucket — pass a unique suffix in as a variable
bucket = "test-myapp-${var.test_suffix}"
# e.g. terraform test -var 'test_suffix=x9k2', or a tests/setup module using random_pet
```

Avoid `timestamp()` or `uuid()` in resource names: they change on every plan, forcing replacement whenever a test file contains more than one `apply` run.

Lambda function names, IAM role names, and CloudWatch log group names also have global-per-account-per-region uniqueness; apply the same suffix pattern.

General AWS naming: lowercase letters, numbers, and hyphens (`^[a-z0-9-]+$`). Most resource types reject underscores.
