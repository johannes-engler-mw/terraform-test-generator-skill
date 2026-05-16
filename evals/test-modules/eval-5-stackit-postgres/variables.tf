variable "project_id" {
  description = "STACKIT project UUID (8-4-4-4-12)"
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.project_id))
    error_message = "project_id must be a valid UUID (8-4-4-4-12 hex digits)."
  }
}

variable "region" {
  description = "STACKIT region"
  type        = string
  default     = "eu01"

  validation {
    condition     = contains(["eu01"], var.region)
    error_message = "Only eu01 is currently supported."
  }
}

variable "instance_name" {
  description = "Base name applied to both the bucket (with -data suffix) and the postgres instance"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,32}$", var.instance_name))
    error_message = "instance_name must be 2-33 chars, start with a letter, lowercase alphanumeric + hyphens."
  }
}

variable "postgres_version" {
  description = "Postgres major version"
  type        = string

  validation {
    condition     = contains(["14", "15", "16"], var.postgres_version)
    error_message = "postgres_version must be one of 14, 15, 16."
  }
}

variable "acl" {
  description = "Allowed CIDR blocks for Postgres access"
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for cidr in var.acl : !contains(["0.0.0.0/0"], cidr)])
    error_message = "acl must not include 0.0.0.0/0 (public access forbidden)."
  }
}

variable "backup_schedule" {
  description = "Cron schedule for automated backups"
  type        = string
  default     = "0 2 * * *"
}

variable "flavor_cpu" {
  description = "CPU cores per instance"
  type        = number
  default     = 2
}

variable "flavor_ram" {
  description = "RAM (GB) per instance"
  type        = number
  default     = 4
}

variable "replicas" {
  description = "Number of replicas (1 = single instance, >=2 = HA)"
  type        = number
  default     = 1

  validation {
    condition     = var.replicas >= 1 && var.replicas <= 5
    error_message = "replicas must be between 1 and 5."
  }
}

variable "storage_class" {
  description = "Storage class"
  type        = string
  default     = "premium-perf2-stackit"
}

variable "storage_size_gb" {
  description = "Storage size in GB"
  type        = number
  default     = 20

  validation {
    condition     = var.storage_size_gb >= 5 && var.storage_size_gb <= 5000
    error_message = "storage_size_gb must be between 5 and 5000."
  }
}
