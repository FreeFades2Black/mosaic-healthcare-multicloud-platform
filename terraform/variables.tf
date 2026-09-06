# --------------------------------------------------------------------------------------------------
# GUNSLINGER MANIFEST: SYSTEM ATTRIBUTES & FRONTIER BOUNDS
# Mosaic Healthcare Multi-Cloud Production Configuration
# --------------------------------------------------------------------------------------------------

# --- Global & Environment Variables ---
variable "environment" {
  description = "Target deployment tier (e.g., prod, stage, dev)"
  type        = string
  default     = "prod"

  validation {
    condition     = contains(["dev", "stage", "prod"], var.environment)
    error_message = "Environment must be one of: dev, stage, prod."
  }
}

variable "organization_prefix" {
  description = "Standard naming prefix across all cloud assets"
  type        = string
  default     = "mosaic"
}

# --- AWS Foundation Variables ---
variable "aws_region" {
  description = "AWS operational region for Mosaic compute & storage"
  type        = string
  default     = "us-east-1"
}

variable "aws_account_id" {
  description = "AWS 12-digit production account identifier"
  type        = string
  default     = "111122223333"

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "The AWS account ID must be exactly 12 numeric digits."
  }
}

variable "aws_vpc_cidr" {
  description = "CIDR block for the AWS Databricks customer-managed E-VPC"
  type        = string
  default     = "10.150.0.0/16"
}

variable "aws_private_subnets" {
  description = "CIDR blocks for Databricks cluster nodes in AWS"
  type        = list(string)
  default     = ["10.150.10.0/24", "10.150.20.0/24"]
}

# --- Azure Foundation Variables ---
variable "azure_subscription_id" {
  description = "Azure enterprise subscription ID for healthcare production"
  type        = string
  default     = "a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d"
}

variable "azure_tenant_id" {
  description = "Azure Entra ID (Azure AD) Directory/Tenant ID"
  type        = string
  default     = "f9e8d7c6-b5a4-3210-fedc-ba9876543210"
}

variable "azure_region" {
  description = "Primary Azure region for clinical VNet and ADLS Gen2"
  type        = string
  default     = "eastus"
}

variable "azure_resource_group_name" {
  description = "Name of the existing or target resource group for Databricks"
  type        = string
  default     = "rg-mosaic-healthcare-prod-eastus"
}

variable "azure_vnet_cidr" {
  description = "CIDR address space for Azure Databricks VNet Injection"
  type        = string
  default     = "10.180.0.0/16"
}

variable "azure_host_subnet_cidr" {
  description = "Delegated private subnet for Databricks host/driver pods"
  type        = string
  default     = "10.180.1.0/24"
}

variable "azure_container_subnet_cidr" {
  description = "Delegated private subnet for Databricks container/worker pods"
  type        = string
  default     = "10.180.2.0/24"
}

# --- Databricks & Unity Catalog Variables ---
variable "databricks_account_id" {
  description = "Databricks Unified Account Console ID for Unity Catalog administration"
  type        = string
  default     = "98765432-abcd-ef01-2345-6789abcdef01"
}

variable "databricks_client_id" {
  description = "Databricks service principal OAuth client ID for administrative automations"
  type        = string
  sensitive   = true
  default     = "sp-mosaic-terraform-deployer@mosaic-prod"
}

variable "databricks_client_secret" {
  description = "Databricks service principal OAuth client secret"
  type        = string
  sensitive   = true
  default     = "placeholder-secret-set-via-env"
}

variable "databricks_workspace_url" {
  description = "Hostname for the deployed Databricks production workspace"
  type        = string
  default     = "https://dbc-mosaic-healthcare-prod.cloud.databricks.com"
}

variable "databricks_api_token" {
  description = "Workspace Personal Access Token or Service Principal PAT"
  type        = string
  sensitive   = true
  default     = "placeholder-token"
}

# --- Medallion Data Tiering & Governance ---
variable "medallion_tiers" {
  description = "Standard lakehouse layers deployed across AWS S3 and Azure ADLS Gen2"
  type        = list(string)
  default     = ["bronze-raw", "silver-cleansed", "gold-curated"]
}

variable "hipaa_audit_retention_days" {
  description = "Storage retention timeline for CloudTrail, NSG Flow Logs, and access audits"
  type        = number
  default     = 2555 # 7 years required under healthcare compliance guidelines
}
