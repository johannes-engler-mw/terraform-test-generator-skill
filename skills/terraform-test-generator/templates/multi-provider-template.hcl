# Multi-Provider Test Template
# File naming: tests/multi_provider_<feature_name>.tftest.hcl
# Use when testing modules that use multiple cloud providers simultaneously

# Define ALL mock providers used in the module
mock_provider "aws" {
  alias = "mock_aws"
}

mock_provider "azurerm" {
  alias = "mock_azure"
}

mock_provider "google" {
  alias = "mock_gcp"
}

mock_provider "stackit" {
  alias = "mock_stackit"
}

# Pattern 1: Testing AWS + Azure multi-cloud setup
run "test_aws_azure_integration" {
  command = plan

  # Reference ALL mock providers
  providers = {
    aws      = aws.mock_aws
    azurerm  = azurerm.mock_azure
  }

  # Mock AWS data sources
  override_data {
    target = data.aws_availability_zones.available
    values = {
      names    = ["us-east-1a", "us-east-1b"]
      zone_ids = ["use1-az1", "use1-az2"]
    }
  }

  override_data {
    target = data.aws_caller_identity.current
    values = {
      account_id = "123456789012"
      arn        = "arn:aws:iam::123456789012:root"
      user_id    = "AIDACKCEVSQ6C2EXAMPLE"
    }
  }

  # Mock Azure data sources
  override_data {
    target = data.azurerm_client_config.current
    values = {
      tenant_id       = "12345678-1234-1234-1234-123456789012"
      subscription_id = "87654321-4321-4321-4321-210987654321"
      client_id       = "abcdef12-3456-7890-abcd-ef1234567890"
      object_id       = "11111111-1111-1111-1111-111111111111"
    }
  }

  variables {
    # AWS-specific variables
    aws_region     = "us-east-1"
    aws_vpc_cidr   = "10.0.0.0/16"

    # Azure-specific variables
    azure_location = "eastus"
    azure_vnet_cidr = "10.1.0.0/16"

    # Common variables
    project_name   = "multi-cloud-test"
    environment    = "test"
    # ... all other required variables
  }

  # Test AWS resources
  assert {
    condition     = aws_vpc.main.cidr_block == var.aws_vpc_cidr
    error_message = "AWS VPC CIDR should match input"
  }

  # Test Azure resources
  assert {
    condition     = azurerm_virtual_network.main.address_space[0] == var.azure_vnet_cidr
    error_message = "Azure VNet CIDR should match input"
  }

  # Test cross-cloud consistency
  assert {
    condition     = aws_vpc.main.tags["Project"] == azurerm_virtual_network.main.tags["Project"]
    error_message = "Resources across clouds should have consistent tagging"
  }
}

# Pattern 2: Testing AWS + GCP multi-cloud setup
run "test_aws_gcp_integration" {
  command = plan

  providers = {
    aws    = aws.mock_aws
    google = google.mock_gcp
  }

  # Mock AWS data sources
  override_data {
    target = data.aws_availability_zones.available
    values = {
      names    = ["us-east-1a", "us-east-1b"]
      zone_ids = ["use1-az1", "use1-az2"]
    }
  }

  # Mock GCP data sources
  override_data {
    target = data.google_project.current
    values = {
      project_id = "test-project-12345"
      number     = "123456789012"
      name       = "Test Project"
    }
  }

  override_data {
    target = data.google_compute_zones.available
    values = {
      names = ["us-central1-a", "us-central1-b", "us-central1-c"]
    }
  }

  variables {
    # AWS-specific
    aws_region   = "us-east-1"
    aws_vpc_cidr = "10.0.0.0/16"

    # GCP-specific
    gcp_project = "test-project-12345"
    gcp_region  = "us-central1"
    gcp_network_cidr = "10.2.0.0/16"

    # Common
    project_name = "multi-cloud-test"
    environment  = "test"
    # ... all other required variables
  }

  # Test AWS S3 bucket
  assert {
    condition     = length(aws_s3_bucket.main) > 0
    error_message = "AWS S3 bucket should be configured"
  }

  # Test GCP storage bucket
  assert {
    condition     = length(google_storage_bucket.main) > 0
    error_message = "GCP storage bucket should be configured"
  }

  # Test naming consistency
  assert {
    condition     = can(regex("^${var.project_name}-", aws_s3_bucket.main.bucket)) && can(regex("^${var.project_name}-", google_storage_bucket.main.name))
    error_message = "Storage buckets across clouds should follow consistent naming convention"
  }
}

# Pattern 3: Testing provider aliases (multiple instances of same provider)
# Example: Multiple AWS regions or multiple Azure subscriptions
mock_provider "aws" {
  alias = "mock_primary"
}

mock_provider "aws" {
  alias = "mock_dr"  # Disaster recovery region
}

run "test_multi_region_aws" {
  command = plan

  # Map provider aliases to mock providers
  providers = {
    aws.primary = aws.mock_primary
    aws.dr      = aws.mock_dr
  }

  # Mock data for primary region
  override_data {
    target = data.aws_availability_zones.primary
    values = {
      names    = ["us-east-1a", "us-east-1b"]
      zone_ids = ["use1-az1", "use1-az2"]
    }
  }

  # Mock data for DR region
  override_data {
    target = data.aws_availability_zones.dr
    values = {
      names    = ["us-west-2a", "us-west-2b"]
      zone_ids = ["usw2-az1", "usw2-az2"]
    }
  }

  variables {
    primary_region = "us-east-1"
    dr_region      = "us-west-2"
    project_name   = "multi-region-test"
    environment    = "test"
    vpc_cidr       = "10.0.0.0/16"
    # ... all other required variables
  }

  # Test primary region resources
  assert {
    condition     = aws_vpc.primary.cidr_block == var.vpc_cidr
    error_message = "Primary VPC should be configured correctly"
  }

  # Test DR region resources
  assert {
    condition     = aws_vpc.dr.cidr_block == var.vpc_cidr
    error_message = "DR VPC should match primary VPC configuration"
  }

  # Test region-specific tags
  assert {
    condition     = aws_vpc.primary.tags["Region"] == var.primary_region && aws_vpc.dr.tags["Region"] == var.dr_region
    error_message = "VPCs should be tagged with their respective regions"
  }
}

# Pattern 4: Testing cross-provider data sharing
run "test_cross_provider_data_sharing" {
  command = plan

  providers = {
    aws      = aws.mock_aws
    azurerm  = azurerm.mock_azure
  }

  # Mock AWS data sources
  override_data {
    target = data.aws_s3_bucket.shared
    values = {
      id     = "shared-bucket-12345"
      arn    = "arn:aws:s3:::shared-bucket-12345"
      region = "us-east-1"
      bucket = "shared-bucket-12345"
    }
  }

  # Mock Azure data sources
  override_data {
    target = data.azurerm_storage_account.shared
    values = {
      id                   = "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/test-rg/providers/Microsoft.Storage/storageAccounts/sharedsa12345"
      name                 = "sharedsa12345"
      primary_blob_endpoint = "https://sharedsa12345.blob.core.windows.net/"
    }
  }

  variables {
    aws_bucket_name        = "shared-bucket-12345"
    azure_storage_account  = "sharedsa12345"
    enable_cross_cloud_sync = true
    project_name           = "cross-cloud-test"
    environment            = "test"
    # ... all other required variables
  }

  # Test that both cloud storage resources are configured
  assert {
    condition     = length(aws_s3_bucket.main) > 0 && length(azurerm_storage_account.main) > 0
    error_message = "Both AWS and Azure storage should be configured"
  }

  # Test data sharing configuration
  assert {
    condition     = var.enable_cross_cloud_sync ? length(aws_lambda_function.sync) > 0 || length(azurerm_function_app.sync) > 0 : true
    error_message = "Cross-cloud sync function should be configured when enabled"
  }
}

# Pattern 5: Testing provider version requirements
run "test_provider_compatibility" {
  command = plan

  providers = {
    aws      = aws.mock_aws
    azurerm  = azurerm.mock_azure
    google   = google.mock_gcp
  }

  # Mock all necessary data sources
  override_data {
    target = data.aws_availability_zones.available
    values = {
      names = ["us-east-1a", "us-east-1b"]
    }
  }

  override_data {
    target = data.azurerm_client_config.current
    values = {
      tenant_id       = "12345678-1234-1234-1234-123456789012"
      subscription_id = "87654321-4321-4321-4321-210987654321"
    }
  }

  override_data {
    target = data.google_project.current
    values = {
      project_id = "test-project-12345"
    }
  }

  variables {
    # Multi-cloud variables
    aws_region     = "us-east-1"
    azure_location = "eastus"
    gcp_region     = "us-central1"
    project_name   = "compat-test"
    environment    = "test"
    # ... all other required variables
  }

  # Test resources across all providers are configured
  assert {
    condition     = length(aws_vpc.main) > 0
    error_message = "AWS resources should be configured"
  }

  assert {
    condition     = length(azurerm_virtual_network.main) > 0
    error_message = "Azure resources should be configured"
  }

  assert {
    condition     = length(google_compute_network.main) > 0
    error_message = "GCP resources should be configured"
  }
}

# Pattern 6: Testing conditional provider usage
run "test_conditional_provider" {
  command = plan

  # Define all providers even if conditionally used
  providers = {
    aws     = aws.mock_aws
    azurerm = azurerm.mock_azure
  }

  override_data {
    target = data.aws_availability_zones.available
    values = {
      names = ["us-east-1a", "us-east-1b"]
    }
  }

  override_data {
    target = data.azurerm_client_config.current
    values = {
      tenant_id       = "12345678-1234-1234-1234-123456789012"
      subscription_id = "87654321-4321-4321-4321-210987654321"
    }
  }

  variables {
    project_name    = "conditional-test"
    environment     = "test"
    enable_aws      = true
    enable_azure    = false
    aws_region      = "us-east-1"
    azure_location  = "eastus"
    # ... all other required variables
  }

  # Test AWS resources created when enabled
  assert {
    condition     = var.enable_aws ? length(aws_vpc.main) == 1 : length(aws_vpc.main) == 0
    error_message = "AWS VPC should only be created when enable_aws is true"
  }

  # Test Azure resources not created when disabled
  assert {
    condition     = var.enable_azure ? length(azurerm_virtual_network.main) == 1 : length(azurerm_virtual_network.main) == 0
    error_message = "Azure VNet should only be created when enable_azure is true"
  }
}
