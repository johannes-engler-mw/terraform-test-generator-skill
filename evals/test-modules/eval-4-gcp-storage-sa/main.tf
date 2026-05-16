terraform {
  required_version = ">= 1.6.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

data "google_project" "current" {}

resource "google_storage_bucket" "data" {
  name          = "${var.bucket_prefix}-${var.environment}-${data.google_project.current.number}"
  location      = var.region
  project       = var.project_id
  force_destroy = false

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  encryption {
    default_kms_key_name = var.kms_key_name
  }

  labels = var.labels
}

resource "google_service_account" "app" {
  account_id   = "${var.bucket_prefix}-${var.environment}-sa"
  display_name = "${var.bucket_prefix} ${var.environment} service account"
  project      = var.project_id
}

resource "google_storage_bucket_iam_binding" "app_writer" {
  bucket  = google_storage_bucket.data.name
  role    = "roles/storage.objectAdmin"
  members = [for sa_email in var.additional_writers : "serviceAccount:${sa_email}"]
}

resource "google_storage_bucket_iam_member" "app_member" {
  bucket = google_storage_bucket.data.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.app.email}"
}
