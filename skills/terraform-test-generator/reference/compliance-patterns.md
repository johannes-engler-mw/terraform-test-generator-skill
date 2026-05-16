# Compliance Test Patterns

Concrete assertion patterns for the six compliance areas you'll most often need: tagging/labeling, encryption (at rest and in transit), network security, IAM, logging, and data protection.

Each concept shows one canonical example. The provider-specific resource type differs (AWS `aws_s3_bucket`, Azure `azurerm_storage_account`, GCP `google_storage_bucket`) but the assertion shape is the same — swap the resource reference. Provider-specific gotchas are called out inline.

## Tagging and Labeling

Required tags / labels are the workhorse compliance check. AWS and Azure call them "tags" (Pascal-case keys conventional); GCP calls them "labels" and requires lowercase keys and values.

```hcl
# AWS / Azure (tags)
assert {
  condition = alltrue([
    contains(keys(aws_instance.main.tags), "Environment"),
    contains(keys(aws_instance.main.tags), "Project"),
    contains(keys(aws_instance.main.tags), "Owner"),
  ])
  error_message = "Resource must have Environment, Project, and Owner tags"
}

# GCP (labels — lowercase keys)
assert {
  condition = alltrue([
    contains(keys(google_storage_bucket.main.labels), "environment"),
    contains(keys(google_storage_bucket.main.labels), "project"),
    contains(keys(google_storage_bucket.main.labels), "owner"),
  ])
  error_message = "Resource must have environment, project, and owner labels"
}
```

For value-shape constraints (e.g. cost-center format, environment-name regex):

```hcl
assert {
  condition     = can(regex("^(dev|staging|prod)$", aws_instance.main.tags["Environment"]))
  error_message = "Environment tag must be dev, staging, or prod"
}
```

## Encryption at Rest

### Storage (S3 / Storage Account / GCS Bucket)

```hcl
# AWS S3 — require KMS (not just AES256)
assert {
  condition     = aws_s3_bucket_server_side_encryption_configuration.main.rule[0].apply_server_side_encryption_by_default[0].sse_algorithm == "aws:kms"
  error_message = "S3 bucket must use KMS encryption"
}

# Azure Storage — require customer-managed key
assert {
  condition     = length(azurerm_storage_account.main.customer_managed_key) > 0
  error_message = "Storage account must use a customer-managed key"
}

# GCP Storage — require CMEK
assert {
  condition     = google_storage_bucket.main.encryption[0].default_kms_key_name != null
  error_message = "Storage bucket must use a customer-managed encryption key"
}
```

The `rule[0]` and `apply_server_side_encryption_by_default[0]` indexes are list-type (not sets) — `[0]` is correct here. Same for Azure's `customer_managed_key[0]` and GCP's `encryption[0]`.

### Databases

```hcl
# AWS RDS
assert {
  condition     = aws_db_instance.main.storage_encrypted == true
  error_message = "RDS instance must have storage encryption enabled"
}
assert {
  condition     = aws_db_instance.main.kms_key_id != null
  error_message = "RDS instance must use a KMS-managed key"
}

# Azure PostgreSQL Flexible Server
assert {
  condition     = azurerm_postgresql_flexible_server.main.customer_managed_key[0].key_vault_key_id != null
  error_message = "PostgreSQL server must use a customer-managed key"
}

# GCP Cloud SQL
assert {
  condition     = google_sql_database_instance.main.settings[0].disk_encryption_configuration[0].kms_key_name != null
  error_message = "SQL instance must use a customer-managed encryption key"
}
```

### Block storage / disks

```hcl
# AWS EBS
assert { condition = aws_ebs_volume.main.encrypted == true, error_message = "EBS volume must be encrypted" }

# GCP Persistent Disk
assert { condition = google_compute_disk.main.disk_encryption_key != null, error_message = "Compute disk must be encrypted" }
```

## Encryption in Transit

```hcl
# AWS — HTTPS-only listener
assert {
  condition     = aws_lb_listener.main.protocol == "HTTPS"
  error_message = "Load-balancer listener must use HTTPS"
}

# Azure — TLS 1.2 minimum on storage
assert {
  condition     = azurerm_storage_account.main.min_tls_version == "TLS1_2"
  error_message = "Storage account must require TLS 1.2 or higher"
}

# GCP — require SSL on Cloud SQL
assert {
  condition     = google_sql_database_instance.main.settings[0].ip_configuration[0].require_ssl == true
  error_message = "SQL instance must require SSL connections"
}
```

## Network Security

### No unrestricted ingress (the canonical 0.0.0.0/0 check)

Security-group and firewall rules use set-type collections, so always iterate with `for` — never `[0]`.

```hcl
# AWS Security Group
assert {
  condition     = length([for rule in aws_security_group.main.ingress : rule if contains(rule.cidr_blocks, "0.0.0.0/0")]) == 0
  error_message = "Security groups must not allow ingress from 0.0.0.0/0"
}

# Azure NSG rule (single rule, not a set)
assert {
  condition     = azurerm_network_security_rule.main.source_address_prefix != "*"
  error_message = "NSG rule must not allow traffic from any source (*)"
}

# GCP Firewall
assert {
  condition     = length([for r in google_compute_firewall.main.source_ranges : r if r == "0.0.0.0/0"]) == 0
  error_message = "Firewall rules must not allow ingress from 0.0.0.0/0"
}
```

### Specific port restrictions (e.g. SSH not exposed)

```hcl
assert {
  condition     = length([for rule in aws_security_group.main.ingress : rule if rule.from_port == 22 && contains(rule.cidr_blocks, "0.0.0.0/0")]) == 0
  error_message = "SSH (port 22) must not be open to the internet"
}
```

### Public access blocks (storage)

```hcl
# AWS S3
assert { condition = aws_s3_bucket_public_access_block.main.block_public_acls == true,     error_message = "S3 must block public ACLs" }
assert { condition = aws_s3_bucket_public_access_block.main.block_public_policy == true,   error_message = "S3 must block public policies" }

# Azure Storage
assert { condition = azurerm_storage_account.main.allow_nested_items_to_be_public == false, error_message = "Storage must disable public blob access" }
assert { condition = azurerm_storage_account.main.public_network_access_enabled == false,    error_message = "Storage must disable public network access" }

# GCP GCS — uniform access + no allUsers/allAuthenticatedUsers binding
assert { condition = google_storage_bucket.main.uniform_bucket_level_access[0].enabled == true, error_message = "Bucket must use uniform access control" }
assert {
  condition     = length([for b in google_storage_bucket_iam_binding.main : b if b.member == "allUsers" || b.member == "allAuthenticatedUsers"]) == 0
  error_message = "Bucket must not grant public access via IAM"
}
```

## IAM / Access Control

### Least privilege — no wildcard actions or resources

```hcl
# AWS — inspect inline JSON policies
assert {
  condition     = length([for s in jsondecode(aws_iam_policy.main.policy).Statement : s if s.Effect == "Allow" && s.Action == "*"]) == 0
  error_message = "IAM policy must not allow all actions (*)"
}
assert {
  condition     = length([for s in jsondecode(aws_iam_policy.main.policy).Statement : s if s.Effect == "Allow" && s.Resource == "*"]) == 0
  error_message = "IAM policy must not grant access to all resources (*)"
}

# Azure — block Owner-level role assignments
assert {
  condition     = azurerm_role_assignment.main.role_definition_name != "Owner"
  error_message = "Role assignment must not grant Owner role"
}

# GCP — block project-level owner grants
assert {
  condition     = google_project_iam_member.main.role != "roles/owner"
  error_message = "Must not grant roles/owner at project level"
}
```

### Managed identity / service account

```hcl
# Azure VM — managed identity required
assert {
  condition     = length(azurerm_linux_virtual_machine.main.identity) > 0
  error_message = "VM must use managed identity"
}

# AWS IAM role — permissions boundary attached
assert {
  condition     = aws_iam_role.main.permissions_boundary != null
  error_message = "IAM role must have a permissions boundary"
}
```

## Logging and Monitoring

```hcl
# AWS — S3 access logs + RDS log exports
assert { condition = aws_s3_bucket_logging.main.target_bucket != null,         error_message = "S3 bucket must have access logging enabled" }
assert { condition = aws_db_instance.main.enabled_cloudwatch_logs_exports != null, error_message = "RDS must export logs to CloudWatch" }

# Azure — at least one diagnostic setting
assert { condition = length(azurerm_monitor_diagnostic_setting.main) > 0, error_message = "Resource must have diagnostic settings configured" }

# GCP — VPC Flow Logs on subnets
assert { condition = length(google_compute_subnetwork.main.log_config) > 0, error_message = "Subnet must have VPC Flow Logs enabled" }
```

Retention thresholds vary by compliance framework; the typical minimum is 90 days:

```hcl
assert {
  condition     = aws_cloudwatch_log_group.main.retention_in_days >= 90
  error_message = "CloudWatch log group must retain logs for at least 90 days"
}
```

## Data Protection (Backups + Versioning)

```hcl
# AWS — RDS backup retention
assert {
  condition     = aws_db_instance.main.backup_retention_period >= 7
  error_message = "RDS instance must retain backups for at least 7 days"
}

# Azure — database backup retention
assert {
  condition     = azurerm_postgresql_flexible_server.main.backup_retention_days >= 7
  error_message = "Database must retain backups for at least 7 days"
}

# GCP — Cloud SQL automated backups
assert {
  condition     = google_sql_database_instance.main.settings[0].backup_configuration[0].enabled == true
  error_message = "SQL instance must have automated backups enabled"
}
```

```hcl
# S3 / GCS — versioning enabled
assert { condition = aws_s3_bucket_versioning.main.versioning_configuration[0].status == "Enabled", error_message = "S3 must have versioning enabled" }
assert { condition = google_storage_bucket.main.versioning[0].enabled == true,                       error_message = "GCS must have versioning enabled" }

# Azure Storage — soft delete retention
assert {
  condition     = azurerm_storage_account.main.blob_properties[0].delete_retention_policy[0].days >= 7
  error_message = "Storage account must enable soft delete with ≥7 days retention"
}
```

## Framework-Specific Bundles

When a compliance framework is requested (SOC 2, HIPAA, PCI-DSS, etc.), bundle the relevant assertions into a single named run block rather than scattering them. This makes the framework-coverage relationship explicit in the test name.

```hcl
run "soc2_data_protection" {
  command = plan

  providers = { aws = aws.mock }

  variables { /* ... */ }

  # Encryption at rest
  assert {
    condition     = aws_s3_bucket_server_side_encryption_configuration.main.rule[0].apply_server_side_encryption_by_default[0].sse_algorithm == "aws:kms"
    error_message = "SOC 2: data at rest must be encrypted with KMS"
  }

  # Encryption in transit
  assert {
    condition     = aws_lb_listener.main.protocol == "HTTPS"
    error_message = "SOC 2: data in transit must use HTTPS"
  }

  # Audit logging
  assert {
    condition     = aws_s3_bucket_logging.main.target_bucket != null
    error_message = "SOC 2: access logs must be enabled"
  }
}
```

Typical framework→checks mapping:

| Framework | Key compliance areas to assert |
|-----------|--------------------------------|
| SOC 2 | Encryption (rest + transit), audit logging, access controls, backup retention |
| HIPAA | PHI encryption, network isolation (`publicly_accessible == false`), backup retention ≥7d, audit trails |
| PCI-DSS | Strong encryption, network segmentation (no `0.0.0.0/0` to cardholder env), access logging, key rotation |
| GDPR | Encryption, data-deletion mechanisms (versioning + lifecycle policies), audit logs, regional restrictions |

## Custom / Organizational Policies

For requirements not captured by a standard framework, write a one-off `assert` against the relevant attribute:

```hcl
# Cost-center tag mandatory
assert {
  condition     = contains(keys(aws_instance.main.tags), "CostCenter")
  error_message = "Organization policy: all resources must carry a CostCenter tag"
}

# Approved-region whitelist
assert {
  condition     = contains(["us-east-1", "us-west-2", "eu-west-1"], var.region)
  error_message = "Organization policy: deploy only to approved regions"
}

# Naming convention by org prefix
assert {
  condition     = can(regex("^${var.organization_prefix}-[a-z0-9-]+$", aws_instance.main.tags["Name"]))
  error_message = "Organization policy: resource names must follow the org naming convention"
}
```
