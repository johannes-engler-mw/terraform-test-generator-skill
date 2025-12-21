# Azure (azurerm) Provider Patterns

## Contents
- [Azure Mock Provider](#azure-mock-provider)
- [Azure UUID Validation Requirements](#azure-uuid-validation-requirements)
- [Azure Override Data with Valid UUIDs](#azure-override-data-with-valid-uuids)
- [Azure for_each Data Source Mocking](#azure-for_each-data-source-mocking)
- [Azure Data Source Mocking](#azure-data-source-mocking)
- [Azure Computed Attributes](#azure-computed-attributes)
- [Azure Security Tests](#azure-security-tests)
- [Azure Tagging](#azure-tagging)
- [Azure Naming Conventions](#azure-naming-conventions)

## Azure Mock Provider

```hcl
mock_provider "azurerm" {
  alias = "mock"
}

# With resource mocks
mock_provider "azurerm" {
  alias = "mock"

  mock_resource "azurerm_storage_account" {
    defaults = {
      id                   = "/subscriptions/12345/resourceGroups/test-rg/providers/Microsoft.Storage/storageAccounts/teststorage"
      name                 = "teststorage"
      location             = "eastus"
      resource_group_name  = "test-rg"
    }
  }

  mock_resource "azurerm_postgresql_flexible_server" {
    defaults = {
      id                   = "/subscriptions/12345/resourceGroups/test-rg/providers/Microsoft.DBforPostgreSQL/flexibleServers/test-psql"
      name                 = "test-psql"
      location             = "eastus"
      resource_group_name  = "test-rg"
      fqdn                 = "test-psql.postgres.database.azure.com"
    }
  }

  mock_resource "azurerm_kubernetes_cluster" {
    defaults = {
      id                   = "/subscriptions/12345/resourceGroups/test-rg/providers/Microsoft.ContainerService/managedClusters/test-aks"
      name                 = "test-aks"
      location             = "eastus"
      resource_group_name  = "test-rg"
      fqdn                 = "test-aks-abcd1234.hcp.eastus.azmk8s.io"
      kubernetes_version   = "1.28.0"
    }
  }

  mock_resource "azurerm_app_service" {
    defaults = {
      id                   = "/subscriptions/12345/resourceGroups/test-rg/providers/Microsoft.Web/sites/test-app"
      name                 = "test-app"
      location             = "eastus"
      resource_group_name  = "test-rg"
      default_site_hostname = "test-app.azurewebsites.net"
    }
  }
}

mock_provider "azuread" {
  alias = "mock_ad"
}
```

## Azure UUID Validation Requirements

**CRITICAL:** Azure providers strictly validate UUID format for identity fields.

**Required UUID Format:** `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` (8-4-4-4-12 hex digits)

**Fields requiring valid UUIDs:**
- `object_id` - User/group/service principal object IDs
- `tenant_id` - Azure AD tenant identifiers
- `subscription_id` - Azure subscription identifiers
- `client_id` - Application/service principal client IDs

**Use realistic UUIDs, not test patterns like all 1s or all 2s:**
```hcl
# ✅ GOOD - Realistic UUID
object_id = "a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d"

# ⚠️ AVOID - Too obvious test pattern
object_id = "11111111-1111-1111-1111-111111111111"
```

## Azure Override Data with Valid UUIDs

```hcl
mock_provider "azurerm" {
  alias = "mock"
}

mock_provider "azuread" {
  alias = "mock_ad"
}

run "test_with_entra_groups" {
  command = plan

  providers = {
    azurerm = azurerm.mock
    azuread = azuread.mock_ad
  }

  # Mock Azure AD group data
  override_data {
    target = data.azuread_group.admin_groups["TestGroup"]
    values = {
      display_name     = "TestGroup"
      object_id        = "a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d"  # Valid UUID
      security_enabled = true
    }
  }

  # Mock client config
  override_data {
    target = data.azurerm_client_config.current
    values = {
      tenant_id       = "87654321-abcd-ef01-2345-210987654321"  # Valid UUID
      subscription_id = "12345678-9abc-def0-1234-56789abcdef0"  # Valid UUID
      object_id       = "abcdefab-1234-5678-9abc-def012345678"  # Valid UUID
      client_id       = "fedcba98-7654-3210-fedc-ba9876543210"  # Valid UUID
    }
  }

  variables {
    enable_entra_id_auth = true
    entra_id_admin_group_display_names = ["TestGroup"]
  }

  assert {
    condition     = length(azurerm_postgresql_flexible_server_active_directory_administrator.entra_admin_groups) == 1
    error_message = "Should create one admin group configuration"
  }
}
```

## Azure for_each Data Source Mocking

When data sources use `for_each`, mock EACH instance using the exact key:

```hcl
# Module has: data "azuread_group" "admin_groups" { for_each = toset(var.group_names) }

run "test_multiple_groups" {
  providers = {
    azurerm = azurerm.mock
    azuread = azuread.mock_ad
  }

  # Mock each group individually
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

  variables {
    entra_id_admin_group_display_names = [
      "Azure_PostgreSQL_Admin",
      "Azure_PostgreSQL_DevOps"
    ]
  }
}
```

## Azure Data Source Mocking

```hcl
# Mock client config
override_data {
  target = data.azurerm_client_config.current
  values = {
    tenant_id       = "12345678-abcd-ef01-2345-6789abcdef01"
    subscription_id = "87654321-fedc-ba98-7654-321098765432"
    object_id       = "abcdefab-1234-5678-9abc-def012345678"
    client_id       = "11111111-2222-3333-4444-555555555555"
  }
}

# Mock AD group (single instance)
override_data {
  target = data.azuread_group.admin_group
  values = {
    display_name     = "AdminGroup"
    object_id        = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
    security_enabled = true
    mail_enabled     = false
  }
}

# Mock AD groups with for_each (EACH instance must be mocked)
override_data {
  target = data.azuread_group.admin_groups["GroupA"]
  values = {
    display_name     = "GroupA"
    object_id        = "22222222-3333-4444-5555-666666666666"
    security_enabled = true
  }
}

override_data {
  target = data.azuread_group.admin_groups["GroupB"]
  values = {
    display_name     = "GroupB"
    object_id        = "33333333-4444-5555-6666-777777777777"
    security_enabled = true
  }
}

# Mock resource group
override_data {
  target = data.azurerm_resource_group.main
  values = {
    id       = "/subscriptions/12345678-abcd-ef01-2345-6789abcdef01/resourceGroups/test-rg"
    name     = "test-rg"
    location = "eastus"
  }
}

# Mock subscription
override_data {
  target = data.azurerm_subscription.current
  values = {
    subscription_id = "12345678-abcd-ef01-2345-6789abcdef01"
    display_name    = "Test Subscription"
    tenant_id       = "87654321-fedc-ba98-7654-321098765432"
  }
}
```

## Azure Computed Attributes

**Avoid with `command = plan`:** `.id`, `.resource_group_name` (when referencing), `.principal_id`, `.identity`, or any cross-resource references.

**See [common-patterns.md](common-patterns.md#command-selection-quick-reference) for complete command selection rules.**

## Azure Security Tests

```hcl
# Storage account encryption with CMK
assert {
  condition = azurerm_storage_account.main.customer_managed_key[0].key_vault_key_id != null
  error_message = "Storage account must use customer-managed keys"
}

# Network security group rules
assert {
  condition = azurerm_network_security_rule.main.priority >= 100 && azurerm_network_security_rule.main.priority <= 4096
  error_message = "NSG rule priority should be between 100 and 4096"
}

# Disable public blob access
assert {
  condition = azurerm_storage_account.main.allow_nested_items_to_be_public == false
  error_message = "Storage account must disable public blob access"
}

# Managed identity usage
assert {
  condition = length(azurerm_linux_virtual_machine.main.identity) > 0
  error_message = "VM must use managed identity"
}
```

## Azure Tagging

```hcl
assert {
  condition = alltrue([
    contains(keys(azurerm_resource_group.main.tags), "Environment"),
    contains(keys(azurerm_resource_group.main.tags), "Project"),
    contains(keys(azurerm_resource_group.main.tags), "Owner")
  ])
  error_message = "Resource must have Environment, Project, and Owner tags"
}
```

## Azure Naming Conventions

```hcl
# Storage account naming
assert {
  condition = length(var.storage_account_name) >= 3 && length(var.storage_account_name) <= 24
  error_message = "Azure storage account names must be 3-24 characters"
}

assert {
  condition = can(regex("^[a-z0-9]+$", var.storage_account_name))
  error_message = "Azure storage account names must be lowercase alphanumeric only"
}
```
