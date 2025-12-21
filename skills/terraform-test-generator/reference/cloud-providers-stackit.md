# STACKIT Provider Patterns

## Contents
- [STACKIT Mock Provider](#stackit-mock-provider)
- [Common Data Sources](#common-data-sources)
- [Computed Attributes](#computed-attributes)
- [Authentication](#authentication)
- [Project Context](#project-context)

## STACKIT Mock Provider

```hcl
mock_provider "stackit" {
  alias = "mock"
}

# With resource mocks
mock_provider "stackit" {
  alias = "mock"

  mock_resource "stackit_ske_cluster" {
    defaults = {
      id                = "test-cluster-id-123"
      name              = "test-ske-cluster"
      project_id        = "test-project-456"
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

  mock_resource "stackit_mariadb_instance" {
    defaults = {
      id         = "test-mariadb-id"
      name       = "test-mariadb"
      project_id = "test-project-456"
      version    = "10.6"
    }
  }

  mock_resource "stackit_opensearch_instance" {
    defaults = {
      id         = "test-opensearch-id"
      name       = "test-opensearch"
      project_id = "test-project-456"
      version    = "2.8"
    }
  }

  mock_resource "stackit_rabbitmq_instance" {
    defaults = {
      id         = "test-rabbitmq-id"
      name       = "test-rabbitmq"
      project_id = "test-project-456"
      version    = "3.12"
    }
  }

  mock_resource "stackit_logme_instance" {
    defaults = {
      id         = "test-logme-id"
      name       = "test-logme"
      project_id = "test-project-456"
    }
  }

  mock_resource "stackit_network" {
    defaults = {
      id         = "test-network-id"
      name       = "test-network"
      project_id = "test-project-456"
    }
  }

  mock_resource "stackit_server" {
    defaults = {
      id         = "test-server-id"
      name       = "test-server"
      project_id = "test-project-456"
    }
  }
}
```

## Common Data Sources

```hcl
override_data {
  target = data.stackit_project.current
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

## Computed Attributes

Avoid with `command = plan`:
- `.id` - Resource ID
- `.endpoint` - Service endpoints
- `.connection_string` - Database connections

## Authentication

STACKIT uses service account key flow. No credentials needed in tests - mock provider handles authentication.

## Project Context

Most STACKIT resources require `project_id`. Always include in mocks and variable defaults.
