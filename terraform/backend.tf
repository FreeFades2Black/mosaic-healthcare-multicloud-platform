# --------------------------------------------------------------------------------------------------
# GUNSLINGER DISPATCH: S3 TALLY & DYNAMO LOCK
# "Every bullet counted, every trail ledgered in cold iron."
# Mosaic Healthcare Multi-Cloud Production Configuration
# Target: AWS + Azure + Databricks Unity Catalog Enterprise Deployment
# --------------------------------------------------------------------------------------------------

terraform {
  required_version = ">= 1.6.0"

  # AWS S3 Remote Backend with DynamoDB State Locking and Server-Side Encryption
  backend "s3" {
    bucket         = "mosaic-healthcare-tfstate-prod-useast1"
    key            = "foundation/multi-cloud/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "mosaic-healthcare-tflocks-prod"
    encrypt        = true
    kms_key_id     = "arn:aws:kms:us-east-1:111122223333:key/mosaic-tfstate-kms-prod"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.95.0"
    }
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.40.0"
    }
  }
}

# --------------------------------------------------------------------------------------------------
# GUNSLINGER PROVIDERS: THE MARSHALS OF THREE BORDERS
# --------------------------------------------------------------------------------------------------

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = "Mosaic-Healthcare-Platform"
      ManagedBy   = "Terraform"
      Compliance  = "HIPAA-HITRUST"
      DataOwner   = "Mosaic-Data-Governance"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }
  subscription_id = var.azure_subscription_id
  tenant_id       = var.azure_tenant_id
}

# Databricks Account-level provider (for Unity Catalog Metastore & E2 provisioning)
provider "databricks" {
  alias         = "mws"
  host          = "https://accounts.cloud.databricks.com"
  account_id    = var.databricks_account_id
  client_id     = var.databricks_client_id
  client_secret = var.databricks_client_secret
}

# Databricks Workspace-level provider (Workspace artifacts, catalogs, compute)
provider "databricks" {
  alias = "workspace"
  host  = var.databricks_workspace_url
  token = var.databricks_api_token
}
