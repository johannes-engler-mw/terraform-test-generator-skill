terraform {
  required_version = ">= 1.6.0"
  required_providers {
    stackit = {
      source  = "stackitcloud/stackit"
      version = "~> 0.30"
    }
  }
}

provider "stackit" {
  region = var.region
}

data "stackit_resourcemanager_project" "current" {
  project_id = var.project_id
}

resource "stackit_objectstorage_bucket" "data" {
  project_id = data.stackit_resourcemanager_project.current.project_id
  name       = "${var.instance_name}-data"
}

resource "stackit_postgresflex_instance" "db" {
  project_id      = data.stackit_resourcemanager_project.current.project_id
  name            = var.instance_name
  acl             = var.acl
  backup_schedule = var.backup_schedule
  flavor = {
    cpu = var.flavor_cpu
    ram = var.flavor_ram
  }
  replicas = var.replicas
  storage = {
    class = var.storage_class
    size  = var.storage_size_gb
  }
  version = var.postgres_version
}
