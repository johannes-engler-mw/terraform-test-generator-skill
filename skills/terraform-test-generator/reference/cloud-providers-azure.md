# Azure (azurerm) Provider Patterns

This file covers Azure-specific quirks. For shared rules (mock-provider basics, `[0]` on sets, computed attributes under `plan`, single-line conditions, generic security/tagging assertions), see [anti-patterns.md](anti-patterns.md) and [compliance-patterns.md](compliance-patterns.md).

## UUID validation — Azure's biggest gotcha

The `azurerm` and `azuread` providers strictly validate identity fields against the UUID format `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` (8-4-4-4 hex + 12 hex). Any mocked value that isn't a real-shaped UUID will be rejected — and the error message blames the resource, not your mock, so the bug is hard to trace.

Fields that require valid UUIDs:
- `object_id` — user/group/service-principal object IDs
- `tenant_id` — Azure AD tenant identifiers
- `subscription_id` — Azure subscription identifiers
- `client_id` — application/service-principal client IDs

Prefer scattered hex digits over visibly-synthetic patterns (`11111111-1111-...`) so a glance at the value confirms it looks plausible:

```hcl
# ✅ realistic
object_id = "a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d"

# ⚠️ also valid but harder to scan
object_id = "11111111-1111-1111-1111-111111111111"
```

## Mock provider with resource defaults

Most Azure resource IDs follow `/subscriptions/<uuid>/resourceGroups/<name>/providers/Microsoft.<Service>/<type>/<name>`. Use synthetic UUIDs in the subscription segment:

```hcl
mock_provider "azurerm" {
  alias = "mock"

  mock_resource "azurerm_storage_account" {
    defaults = {
      id                  = "/subscriptions/12345678-abcd-ef01-2345-6789abcdef01/resourceGroups/test-rg/providers/Microsoft.Storage/storageAccounts/teststorage"
      name                = "teststorage"
      location            = "eastus"
      resource_group_name = "test-rg"
    }
  }

  mock_resource "azurerm_postgresql_flexible_server" {
    defaults = {
      id                  = "/subscriptions/12345678-abcd-ef01-2345-6789abcdef01/resourceGroups/test-rg/providers/Microsoft.DBforPostgreSQL/flexibleServers/test-psql"
      name                = "test-psql"
      location            = "eastus"
      resource_group_name = "test-rg"
      fqdn                = "test-psql.postgres.database.azure.com"
    }
  }
}

mock_provider "azuread" {
  alias = "mock_ad"
}
```

## Data source mocking

```hcl
override_data {
  target = data.azurerm_client_config.current
  values = {
    tenant_id       = "87654321-abcd-ef01-2345-210987654321"
    subscription_id = "12345678-9abc-def0-1234-56789abcdef0"
    object_id       = "abcdefab-1234-5678-9abc-def012345678"
    client_id       = "fedcba98-7654-3210-fedc-ba9876543210"
  }
}

override_data {
  target = data.azurerm_resource_group.main
  values = {
    id       = "/subscriptions/12345678-abcd-ef01-2345-6789abcdef01/resourceGroups/test-rg"
    name     = "test-rg"
    location = "eastus"
  }
}

override_data {
  target = data.azuread_group.admin_group
  values = {
    display_name     = "AdminGroup"
    object_id        = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
    security_enabled = true
    mail_enabled     = false
  }
}
```

## `for_each` data sources — mock every instance

When a module declares `data "azuread_group" "admin_groups" { for_each = toset(var.group_names) }`, you need a separate `override_data` block for **each** key. Missing keys cause confusing "could not find resource" errors.

```hcl
override_data {
  target = data.azuread_group.admin_groups["Azure_PostgreSQL_Admin"]
  values = {
    display_name     = "Azure_PostgreSQL_Admin"
    object_id        = "44444444-5555-6666-7777-888888888888"
    security_enabled = true
  }
}

override_data {
  target = data.azuread_group.admin_groups["Azure_PostgreSQL_DevOps"]
  values = {
    display_name     = "Azure_PostgreSQL_DevOps"
    object_id        = "99999999-aaaa-bbbb-cccc-dddddddddddd"
    security_enabled = true
  }
}
```

## Naming-convention quirks

| Resource | Constraint |
|----------|-----------|
| `azurerm_storage_account` | 3–24 chars, **lowercase alphanumeric only** (no hyphens, no underscores) |
| `azurerm_key_vault` | 3–24 chars, alphanumeric and hyphens, must start with letter |
| `azurerm_resource_group` | 1–90 chars, alphanumeric + `_.-()`, globally unique within subscription |
| `azurerm_postgresql_flexible_server` | 3–63 chars, lowercase alphanumeric + hyphens, must start with letter |

Storage account names are particularly restrictive — `test_storage` and `test-storage` both fail. Use `teststorage` or `tftestx9k2st` style instead.
