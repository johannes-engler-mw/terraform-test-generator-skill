# STACKIT Provider Patterns

This file covers STACKIT-specific quirks. For shared rules (mock-provider basics, `[0]` on sets, computed attributes under `plan`, single-line conditions, generic security/tagging assertions), see [anti-patterns.md](anti-patterns.md) and [compliance-patterns.md](compliance-patterns.md).

## Mock provider with resource defaults

Almost every STACKIT resource requires `project_id`. Use a synthetic value (`test-project-456`) consistently across all mocks and variable defaults:

```hcl
mock_provider "stackit" {
  alias = "mock"

  mock_resource "stackit_ske_cluster" {
    defaults = {
      id                 = "test-cluster-id-123"
      name               = "test-ske-cluster"
      project_id         = "test-project-456"
      kubernetes_version = "1.28"
    }
  }

  mock_resource "stackit_objectstorage_bucket" {
    defaults = {
      id         = "test-bucket-id"
      name       = "test-bucket"
      project_id = "test-project-456"
      region     = "eu01"
    }
  }

  mock_resource "stackit_postgresflex_instance" {
    defaults = {
      id         = "test-postgres-id"
      name       = "test-postgres"
      project_id = "test-project-456"
      version    = "15"
    }
  }

  # Other instance-style resources (mariadb, opensearch, rabbitmq, logme)
  # follow the same shape: id, name, project_id, version.
}
```

## Data source mocking

Note: the provider has **no** `stackit_project` data source — project lookups go through `stackit_resourcemanager_project`.

```hcl
override_data {
  target = data.stackit_resourcemanager_project.current
  values = {
    project_id = "test-project-456"
    name       = "test-project"
  }
}

override_data {
  target = data.stackit_network.main
  values = {
    id         = "test-network-id"
    name       = "main-network"
    project_id = "test-project-456"
  }
}
```

## Computed attributes specific to STACKIT

Treat these as apply-only (in addition to the universal `.id` rule): `.endpoint`, `.connection_string`, any DSN-shaped values returned by managed-data services.

## Authentication and project context

STACKIT uses a service-account key flow in real runs. The `mock_provider` short-circuits this — no credentials are needed for test execution. Every resource declaration must still include `project_id`; missing it surfaces as a confusing "invalid request" rather than a clean validation error.
