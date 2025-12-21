# GCP (Google) Provider Patterns

## Contents
- [GCP Mock Provider](#gcp-mock-provider)
- [GCP Override Patterns](#gcp-override-patterns)
- [GCP Data Source Mocking](#gcp-data-source-mocking)
- [GCP Computed Attributes](#gcp-computed-attributes)
- [GCP Security Tests](#gcp-security-tests)
- [GCP Labeling](#gcp-labeling)
- [GCP Naming Conventions](#gcp-naming-conventions)

## GCP Mock Provider

```hcl
mock_provider "google" {
  alias = "mock"
}

# With resource mocks
mock_provider "google" {
  alias = "mock"

  mock_resource "google_storage_bucket" {
    defaults = {
      id        = "test-bucket"
      name      = "test-bucket"
      location  = "US"
      project   = "test-project-123"
      self_link = "https://www.googleapis.com/storage/v1/b/test-bucket"
    }
  }

  mock_resource "google_compute_instance" {
    defaults = {
      id                     = "projects/test-project/zones/us-central1-a/instances/test-instance"
      name                   = "test-instance"
      zone                   = "us-central1-a"
      machine_type           = "n1-standard-1"
      self_link              = "https://www.googleapis.com/compute/v1/projects/test-project/zones/us-central1-a/instances/test-instance"
      instance_id            = "1234567890123456789"
    }
  }

  mock_resource "google_container_cluster" {
    defaults = {
      id                     = "projects/test-project/locations/us-central1/clusters/test-gke"
      name                   = "test-gke"
      location               = "us-central1"
      endpoint               = "35.192.0.1"
      self_link              = "https://container.googleapis.com/v1/projects/test-project/locations/us-central1/clusters/test-gke"
    }
  }

  mock_resource "google_sql_database_instance" {
    defaults = {
      id                     = "test-project:test-db-instance"
      name                   = "test-db-instance"
      project                = "test-project"
      region                 = "us-central1"
      connection_name        = "test-project:us-central1:test-db-instance"
      self_link              = "https://sqladmin.googleapis.com/sql/v1beta4/projects/test-project/instances/test-db-instance"
    }
  }

  mock_resource "google_cloudfunctions_function" {
    defaults = {
      id                     = "projects/test-project/locations/us-central1/functions/test-function"
      name                   = "test-function"
      region                 = "us-central1"
      runtime                = "python311"
      https_trigger_url      = "https://us-central1-test-project.cloudfunctions.net/test-function"
      self_link              = "https://cloudfunctions.googleapis.com/v1/projects/test-project/locations/us-central1/functions/test-function"
    }
  }
}
```

## GCP Override Patterns

```hcl
mock_provider "google" {
  alias = "mock"
}

run "test_with_gcp_override" {
  command = plan

  providers = {
    google = google.mock
  }

  override_data {
    target = data.google_project.current
    values = {
      project_id = "test-project-123"
      number     = "123456789012"
      name       = "Test Project"
    }
  }

  override_module {
    target = module.vpc
    outputs = {
      network_name       = "test-vpc"
      network_self_link  = "https://www.googleapis.com/compute/v1/projects/test-project/global/networks/test-vpc"
      subnet_names       = ["test-subnet-1", "test-subnet-2"]
    }
  }

  variables {
    project = "test-project-123"
    region  = "us-central1"
  }

  assert {
    condition     = google_storage_bucket.main.storage_class == "STANDARD"
    error_message = "Storage class should be STANDARD"
  }
}
```

## GCP Data Source Mocking

```hcl
# Mock project
override_data {
  target = data.google_project.current
  values = {
    project_id = "my-project-123"
    number     = "123456789012"
    name       = "My Project"
  }
}

# Mock client config
override_data {
  target = data.google_client_config.current
  values = {
    project = "my-project-123"
    region  = "us-central1"
    zone    = "us-central1-a"
  }
}

# Mock compute zones
override_data {
  target = data.google_compute_zones.available
  values = {
    names = ["us-central1-a", "us-central1-b", "us-central1-c"]
  }
}

# Mock compute network
override_data {
  target = data.google_compute_network.main
  values = {
    id         = "projects/my-project-123/global/networks/test-network"
    name       = "test-network"
    self_link  = "https://www.googleapis.com/compute/v1/projects/my-project-123/global/networks/test-network"
  }
}

# Mock service account
override_data {
  target = data.google_service_account.main
  values = {
    account_id = "test-sa"
    email      = "test-sa@my-project-123.iam.gserviceaccount.com"
    unique_id  = "123456789012345678901"
  }
}
```

## GCP Computed Attributes

### Attributes to AVOID with `command = plan`
- `.id` - Resource ID
- `.self_link` - Full resource URL
- `.instance_id` - Instance identifiers
- `.number` - Project number
- `.member` - IAM member identifiers
- Any attribute referencing other resources

### What You CAN Test with `command = plan`
- ✅ Variables: `var.project`, `var.region`
- ✅ Locals: `local.computed_value`
- ✅ Configuration structure: `length(resource.rule)`
- ✅ Static values: `resource.labels["environment"]`
- ✅ Conditional counts: `length(resource)` tests if resource exists

## GCP Security Tests

```hcl
# Storage bucket CMEK
assert {
  condition = google_storage_bucket.main.encryption[0].default_kms_key_name != null
  error_message = "Storage bucket must use customer-managed encryption keys"
}

# Firewall restrictive rules
assert {
  condition = length([for range in google_compute_firewall.main.source_ranges : range if range == "0.0.0.0/0"]) == 0
  error_message = "Firewall rules must not allow unrestricted access"
}

# Uniform bucket access
assert {
  condition = google_storage_bucket.main.uniform_bucket_level_access[0].enabled == true
  error_message = "Storage bucket must use uniform access control"
}

# VPC Flow Logs
assert {
  condition = google_compute_subnetwork.main.log_config[0].aggregation_interval != null
  error_message = "Subnet must have VPC Flow Logs enabled"
}
```

## GCP Labeling

**Note:** GCP uses "labels" (lowercase), not "tags"

```hcl
assert {
  condition = alltrue([
    contains(keys(google_storage_bucket.main.labels), "environment"),
    contains(keys(google_storage_bucket.main.labels), "project"),
    contains(keys(google_storage_bucket.main.labels), "owner")
  ])
  error_message = "Resource must have environment, project, and owner labels (lowercase)"
}
```

## GCP Naming Conventions

```hcl
assert {
  condition = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.bucket_name))
  error_message = "GCP bucket names must start with letter, contain lowercase letters/numbers/hyphens, end with letter/number"
}
```
