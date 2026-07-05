# GCP (Google) Provider Patterns

This file covers Google-Cloud-specific quirks. For shared rules (mock-provider basics, `[0]` on sets, computed attributes under `plan`, single-line conditions, generic security/tagging assertions), see [anti-patterns.md](anti-patterns.md) and [compliance-patterns.md](compliance-patterns.md).

## Mock provider with resource defaults

GCP IDs and self_links follow `projects/<project>/locations/<region>/<type>/<name>` and `https://<api>.googleapis.com/<v>/projects/<project>/...`:

```hcl
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
      id           = "projects/test-project/zones/us-central1-a/instances/test-instance"
      name         = "test-instance"
      zone         = "us-central1-a"
      machine_type = "n1-standard-1"
      self_link    = "https://www.googleapis.com/compute/v1/projects/test-project/zones/us-central1-a/instances/test-instance"
      instance_id  = "1234567890123456789"
    }
  }

  mock_resource "google_sql_database_instance" {
    defaults = {
      id              = "test-project:test-db-instance"
      name            = "test-db-instance"
      project         = "test-project"
      region          = "us-central1"
      connection_name = "test-project:us-central1:test-db-instance"
    }
  }
}
```

## Data source mocking

```hcl
override_data {
  target = data.google_project.current
  values = {
    project_id = "test-project-123"
    number     = "123456789012"
    name       = "Test Project"
  }
}

override_data {
  target = data.google_client_config.current
  values = {
    project = "test-project-123"
    region  = "us-central1"
    zone    = "us-central1-a"
  }
}

override_data {
  target = data.google_compute_zones.available
  values = {
    names = ["us-central1-a", "us-central1-b", "us-central1-c"]
  }
}

override_data {
  target = data.google_service_account.main
  values = {
    account_id = "test-sa"
    email      = "test-sa@test-project-123.iam.gserviceaccount.com"
    unique_id  = "123456789012345678901"
  }
}
```

## Computed attributes specific to GCP

In addition to `.id` and `.arn`-equivalent fields, GCP exposes a few more that change after apply:
- `.self_link` — the canonical full URL
- `.instance_id` — generated numeric ID (distinct from name)
- `.number` — project number (vs `.project_id`)
- `.member` — IAM principal identifiers

Treat all of these as apply-only. That includes **values derived from them**: a bucket name interpolated as `"${var.prefix}-${data.google_project.current.number}"` inherits the computed-ness of `.number`. Don't assert on such a value under plain `command = plan` — either mock the data source with `override_data` in that same run (so the interpolation is fully known) or move the assertion to a mocked `command = apply` run.

## Naming and labeling quirks

- **GCP uses "labels", not "tags"**, and label keys/values must be **lowercase**. A pattern that works on AWS/Azure (`Environment = "test"`) silently does the wrong thing on GCP.
- Bucket names are globally unique across all GCP projects (same risk as S3) — add a unique suffix for integration tests.
- Bucket names must match `^[a-z][a-z0-9-]*[a-z0-9]$` — start with a letter, end with letter/digit, lowercase only.
- Project IDs must be 6–30 chars, start with a letter, lowercase alphanumeric + hyphens.
