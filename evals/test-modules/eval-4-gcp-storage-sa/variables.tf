variable "project_id" {
  description = "GCP project ID where resources will be created"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{5,29}$", var.project_id))
    error_message = "Project ID must be 6-30 chars, start with a letter, and contain only lowercase letters, digits, and hyphens."
  }
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "Environment name"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "bucket_prefix" {
  description = "Prefix for bucket name; final name is suffixed with env and project number for uniqueness"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,20}$", var.bucket_prefix))
    error_message = "Bucket prefix must be 2-21 chars, start with a letter, lowercase alphanumeric + hyphens."
  }
}

variable "kms_key_name" {
  description = "Full resource name of the KMS key for bucket encryption (projects/.../locations/.../keyRings/.../cryptoKeys/...)"
  type        = string

  validation {
    condition     = can(regex("^projects/[^/]+/locations/[^/]+/keyRings/[^/]+/cryptoKeys/[^/]+$", var.kms_key_name))
    error_message = "KMS key name must be the full resource path."
  }
}

variable "additional_writers" {
  description = "Service-account emails granted objectAdmin on the bucket"
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for email in var.additional_writers : !contains(["allUsers", "allAuthenticatedUsers"], email)])
    error_message = "additional_writers must not contain allUsers or allAuthenticatedUsers (public access forbidden)."
  }
}

variable "labels" {
  description = "Labels applied to all resources; keys and values must be lowercase"
  type        = map(string)
  default     = {}

  validation {
    condition     = alltrue([for k, v in var.labels : can(regex("^[a-z][a-z0-9_-]{0,62}$", k)) && can(regex("^[a-z0-9_-]{0,63}$", v))])
    error_message = "Label keys must start with a lowercase letter; values must be lowercase alphanumeric + _ -."
  }
}
