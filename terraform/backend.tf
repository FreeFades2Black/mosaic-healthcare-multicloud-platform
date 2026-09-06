# ==================================================================================================
# TERRAFORM REMOTE STATE BACKEND & MULTI-CLOUD PROVIDER SPECIFICATIONS
# Project: Mosaic Healthcare Multi-Cloud Production Platform
# Target Architecture: AWS (Storage/KMS) + Azure (VNet/ADLS) + Databricks (Unity Catalog Metastore)
# Compliance Framework: HIPAA Security Rule (45 CFR § 164.312) & HITRUST CSF
# ==================================================================================================

terraform {
  # Enforce minimum Terraform core version supporting modern provider feature sets and validation
  required_version = ">= 1.6.0"

  # ------------------------------------------------------------------------------------------------
  # AWS S3 REMOTE STATE BACKEND CONFIGURATION
  # Manages centralized state storage, cryptographic integrity, and concurrency locking
  # ------------------------------------------------------------------------------------------------
  backend "s3" {
    # Central S3 bucket dedicated exclusively to Terraform state storage in US-East-1
    bucket         = "mosaic-healthcare-tfstate-prod-useast1"

    # State file hierarchical path within the S3 bucket for isolated multi-cloud foundation state
    key            = "foundation/multi-cloud/terraform.tfstate"

    # AWS operational region hosting the remote state bucket
    region         = "us-east-1"

    # Amazon DynamoDB table providing atomic state locking to prevent concurrent multi-engineer writes
    dynamodb_table = "mosaic-healthcare-tflocks-prod"

    # Enforces server-side encryption for all state file uploads containing resource metadata
    encrypt        = true

    # AWS KMS Customer Managed Key (CMK) ARN used to encrypt the state payload at rest
    kms_key_id     = "arn:aws:kms:us-east-1:111122223333:key/mosaic-tfstate-kms-prod"
  }

  # ------------------------------------------------------------------------------------------------
  # REQUIRED PROVIDERS MATRIX
  # Explicit provider pinning ensures deterministic binary downloads across CI/CD runners
  # ------------------------------------------------------------------------------------------------
  required_providers {
    # HashiCorp AWS Provider for E-VPC, S3 Medallion storage, KMS keys, and IAM roles
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40.0"
    }

    # HashiCorp AzureRM Provider for Azure Resource Groups, VNets, ADLS Gen2, and Key Vault
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.95.0"
    }

    # Databricks Provider for Account-level MWS metastores and Workspace-level Unity Catalogs
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.40.0"
    }
  }
}

# --------------------------------------------------------------------------------------------------
# AWS PROVIDER INSTANTIATION
# Primary provider for AWS resources with global default resource tagging for cost allocation & audit
# --------------------------------------------------------------------------------------------------
provider "aws" {
  # Target AWS deployment region passed via input variable
  region = var.aws_region

  # Global default tags automatically injected into all provisioned AWS resources for FinOps & HIPAA
  default_tags {
    tags = {
      Environment = var.environment               # Deployment lifecycle tier (prod, stage, dev)
      Project     = "Mosaic-Healthcare-Platform" # Master enterprise initiative identifier
      ManagedBy   = "Terraform"                  # Identifies Infrastructure as Code ownership
      Compliance  = "HIPAA-HITRUST"              # Flags regulatory audit scope for SecOps scanners
      DataOwner   = "Mosaic-Data-Governance"     # Identifies the business entity accountable for data
    }
  }
}

# --------------------------------------------------------------------------------------------------
# AZURE RESOURCE MANAGER PROVIDER INSTANTIATION
# Primary provider for Microsoft Azure Cloud with zero-data-loss Key Vault and Resource Group guards
# --------------------------------------------------------------------------------------------------
provider "azurerm" {
  # Provider feature flags enforcing enterprise data protection controls
  features {
    key_vault {
      # Disables permanent destruction without soft-delete retention to prevent accidental secret loss
      purge_soft_delete_on_destroy    = false

      # Automatically recovers existing soft-deleted key vaults during deployment cycles
      recover_soft_deleted_key_vaults = true
    }

    resource_group {
      # Prevents destructive deletion of the resource group if it contains active clinical assets
      prevent_deletion_if_contains_resources = true
    }
  }

  # Target Azure enterprise subscription identifier
  subscription_id = var.azure_subscription_id

  # Target Azure Entra ID (Azure Active Directory) tenant identifier
  tenant_id       = var.azure_tenant_id
}

# --------------------------------------------------------------------------------------------------
# DATABRICKS ACCOUNT-LEVEL PROVIDER (MWS ALIAS)
# Used for administrative control-plane operations: Unity Catalog Metastore & E2 workspace creation
# --------------------------------------------------------------------------------------------------
provider "databricks" {
  alias         = "mws"                                      # Alias referenced in metastore resources
  host          = "https://accounts.cloud.databricks.com"    # Databricks Multi-Cloud Account Console URL
  account_id    = var.databricks_account_id                  # Databricks Unified Account ID
  client_id     = var.databricks_client_id                  # Service Principal OAuth Client ID
  client_secret = var.databricks_client_secret              # Service Principal OAuth Client Secret
}

# --------------------------------------------------------------------------------------------------
# DATABRICKS WORKSPACE-LEVEL PROVIDER (WORKSPACE ALIAS)
# Used for data-plane operations: Catalogs, Schemas, Storage Credentials, and External Locations
# --------------------------------------------------------------------------------------------------
provider "databricks" {
  alias = "workspace"                                       # Alias referenced in data governance resources
  host  = var.databricks_workspace_url                       # Target Databricks Workspace URL (e.g. dbc-*.cloud)
  token = var.databricks_api_token                          # Workspace administrative Personal Access Token
}
