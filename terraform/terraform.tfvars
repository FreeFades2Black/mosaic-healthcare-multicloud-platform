# ==================================================================================================
# TERRAFORM PRODUCTION VALUES TEMPLATE (`terraform.tfvars`)
# Project: Mosaic Healthcare Multi-Cloud Production Platform
# Security Policy: DO NOT COMMIT REAL CREDENTIALS TO SOURCE CONTROL.
# Pass sensitive secrets via environment variables (e.g. TF_VAR_databricks_client_secret).
# ==================================================================================================

# --- Global Environment Settings ---
environment         = "prod"                     # Active deployment tier
organization_prefix = "mosaic"                   # Standard asset namespace prefix

# --- AWS Production Deployment Target ---
aws_region          = "us-east-1"               # AWS primary data center region
aws_account_id      = "111122223333"            # Target AWS 12-digit production account
aws_vpc_cidr        = "10.150.0.0/16"           # Customer-managed Databricks E-VPC CIDR
aws_private_subnets = [
  "10.150.10.0/24",                             # AWS Private Subnet 1 (AZ us-east-1a)
  "10.150.20.0/24"                              # AWS Private Subnet 2 (AZ us-east-1b)
]

# --- Azure Production Deployment Target ---
azure_subscription_id       = "a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d" # Azure Production Subscription ID
azure_tenant_id             = "f9e8d7c6-b5a4-3210-fedc-ba9876543210" # Azure Entra ID Tenant ID
azure_region                = "eastus"                               # Azure primary region
azure_resource_group_name   = "rg-mosaic-healthcare-prod-eastus"     # Azure Resource Group
azure_vnet_cidr             = "10.180.0.0/16"                        # Azure Databricks VNet Injection CIDR
azure_host_subnet_cidr      = "10.180.1.0/24"                        # Delegated host (driver) subnet
azure_container_subnet_cidr = "10.180.2.0/24"                        # Delegated container (worker) subnet

# --- Databricks Identity & Unity Catalog Configuration ---
databricks_account_id       = "98765432-abcd-ef01-2345-6789abcdef01" # Databricks Unified Account ID
databricks_client_id        = "sp-mosaic-terraform-deployer@mosaic-prod" # Service Principal Client ID
# Note: databricks_client_secret is injected via memory variable TF_VAR_databricks_client_secret

# --- Medallion Data Governance & Compliance Lifecycles ---
medallion_tiers            = ["bronze-raw", "silver-cleansed", "gold-curated"] # Medallion storage layers
hipaa_audit_retention_days = 2555                                              # 7-year HIPAA compliance retention
