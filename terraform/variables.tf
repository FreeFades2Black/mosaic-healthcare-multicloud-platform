# ==================================================================================================
# TERRAFORM PRODUCTION VARIABLE DEFINITIONS & SCHEMA CONSTRAINTS
# Project: Mosaic Healthcare Multi-Cloud Production Platform
# Target Architecture: AWS + Azure + Databricks Unity Catalog Enterprise Deployment
# ==================================================================================================

# --------------------------------------------------------------------------------------------------
# GLOBAL & LIFECYCLE TIER VARIABLES
# --------------------------------------------------------------------------------------------------

# Target deployment tier enforcing strict validation against authorized lifecycle tiers
variable "environment" {
  description = "Target deployment tier (e.g., prod, stage, dev)"
  type        = string
  default     = "prod"

  # Custom validation rule preventing invalid or typo-prone environment values
  validation {
    condition     = contains(["dev", "stage", "prod"], var.environment)
    error_message = "Environment must be one of: dev, stage, prod."
  }
}

# Standard enterprise organization prefix used to namespace cloud assets globally
variable "organization_prefix" {
  description = "Standard naming prefix across all cloud assets"
  type        = string
  default     = "mosaic"
}

# --------------------------------------------------------------------------------------------------
# AWS CLOUD FOUNDATION VARIABLES
# --------------------------------------------------------------------------------------------------

# Primary AWS operational region hosting customer-managed compute, KMS keys, and S3 Medallion storage
variable "aws_region" {
  description = "AWS operational region for Mosaic compute & storage"
  type        = string
  default     = "us-east-1"
}

# AWS 12-digit account identifier validated via strict regular expression
variable "aws_account_id" {
  description = "AWS 12-digit production account identifier"
  type        = string
  default     = "111122223333"

  # Regex validation ensuring the account ID consists of exactly 12 numeric digits
  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "The AWS account ID must be exactly 12 numeric digits."
  }
}

# Dedicated CIDR block allocated for the Databricks Customer-Managed E-VPC
variable "aws_vpc_cidr" {
  description = "CIDR block for the AWS Databricks customer-managed E-VPC"
  type        = string
  default     = "10.150.0.0/16"
}

# Private subnet CIDRs allocated for isolated Databricks driver and worker nodes in AWS
variable "aws_private_subnets" {
  description = "CIDR blocks for Databricks cluster nodes in AWS"
  type        = list(string)
  default     = ["10.150.10.0/24", "10.150.20.0/24"]
}

# --------------------------------------------------------------------------------------------------
# AZURE CLOUD FOUNDATION VARIABLES
# --------------------------------------------------------------------------------------------------

# Azure enterprise subscription ID for healthcare production deployment
variable "azure_subscription_id" {
  description = "Azure enterprise subscription ID for healthcare production"
  type        = string
  default     = "a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d"
}

# Azure Entra ID (Azure Active Directory) Tenant ID for enterprise identity management
variable "azure_tenant_id" {
  description = "Azure Entra ID (Azure AD) Directory/Tenant ID"
  type        = string
  default     = "f9e8d7c6-b5a4-3210-fedc-ba9876543210"
}

# Primary Azure region hosting VNet Injection and ADLS Gen2 Hierarchical Storage Accounts
variable "azure_region" {
  description = "Primary Azure region for clinical VNet and ADLS Gen2"
  type        = string
  default     = "eastus"
}

# Name of the Azure Resource Group encapsulating all clinical compute and networking assets
variable "azure_resource_group_name" {
  description = "Name of the existing or target resource group for Databricks"
  type        = string
  default     = "rg-mosaic-healthcare-prod-eastus"
}

# Address space for the Azure Virtual Network configured for Databricks VNet Injection
variable "azure_vnet_cidr" {
  description = "CIDR address space for Azure Databricks VNet Injection"
  type        = string
  default     = "10.180.0.0/16"
}

# Delegated subnet for Databricks host (driver) pods in Azure VNet
variable "azure_host_subnet_cidr" {
  description = "Delegated private subnet for Databricks host/driver pods"
  type        = string
  default     = "10.180.1.0/24"
}

# Delegated subnet for Databricks container (worker) pods in Azure VNet
variable "azure_container_subnet_cidr" {
  description = "Delegated private subnet for Databricks container/worker pods"
  type        = string
  default     = "10.180.2.0/24"
}

# --------------------------------------------------------------------------------------------------
# DATABRICKS & UNITY CATALOG GOVERNANCE VARIABLES
# --------------------------------------------------------------------------------------------------

# Databricks Unified Account ID for Metastore provisioning and account-level administration
variable "databricks_account_id" {
  description = "Databricks Unified Account Console ID for Unity Catalog administration"
  type        = string
  default     = "98765432-abcd-ef01-2345-6789abcdef01"
}

# Service Principal OAuth Client ID for automated CI/CD deployments (marked sensitive)
variable "databricks_client_id" {
  description = "Databricks service principal OAuth client ID for administrative automations"
  type        = string
  sensitive   = true
  default     = "sp-mosaic-terraform-deployer@mosaic-prod"
}

# Service Principal OAuth Client Secret for secure authentication (marked sensitive)
variable "databricks_client_secret" {
  description = "Databricks service principal OAuth client secret"
  type        = string
  sensitive   = true
  default     = "placeholder-secret-set-via-env"
}

# Canonical workspace URL for the deployed Databricks production workspace
variable "databricks_workspace_url" {
  description = "Hostname for the deployed Databricks production workspace"
  type        = string
  default     = "https://dbc-mosaic-healthcare-prod.cloud.databricks.com"
}

# Personal Access Token or Service Principal token for workspace API authentication (marked sensitive)
variable "databricks_api_token" {
  description = "Workspace Personal Access Token or Service Principal PAT"
  type        = string
  sensitive   = true
  default     = "placeholder-token"
}

# --------------------------------------------------------------------------------------------------
# MEDALLION LAKEHOUSE DATA TIERING & COMPLIANCE VARIABLES
# --------------------------------------------------------------------------------------------------

# List of Medallion architecture storage tiers deployed across AWS S3 and Azure ADLS Gen2
variable "medallion_tiers" {
  description = "Standard lakehouse layers deployed across AWS S3 and Azure ADLS Gen2"
  type        = list(string)
  default     = ["bronze-raw", "silver-cleansed", "gold-curated"]
}

# Mandatory storage retention timeline for HIPAA-regulated audit logs, CloudTrail, and flow logs
variable "hipaa_audit_retention_days" {
  description = "Storage retention timeline for CloudTrail, NSG Flow Logs, and access audits"
  type        = number
  default     = 2555 # Exactly 7 years required under federal HIPAA compliance rules (45 CFR § 164.316)
}
