# --------------------------------------------------------------------------------------------------
# GUNSLINGER CARTRIDGES: PRODUCTION VALUES
# DO NOT COMMIT SECRETS DIRECTLY TO SOURCE CONTROL.
# Pass secrets via environment variables: TF_VAR_databricks_client_secret, etc.
# --------------------------------------------------------------------------------------------------

environment         = "prod"
organization_prefix = "mosaic"

# AWS Production Deployment Target
aws_region          = "us-east-1"
aws_account_id      = "111122223333"
aws_vpc_cidr        = "10.150.0.0/16"
aws_private_subnets = ["10.150.10.0/24", "10.150.20.0/24"]

# Azure Production Deployment Target
azure_subscription_id       = "a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d"
azure_tenant_id             = "f9e8d7c6-b5a4-3210-fedc-ba9876543210"
azure_region                = "eastus"
azure_resource_group_name   = "rg-mosaic-healthcare-prod-eastus"
azure_vnet_cidr             = "10.180.0.0/16"
azure_host_subnet_cidr      = "10.180.1.0/24"
azure_container_subnet_cidr = "10.180.2.0/24"

# Databricks Identity & Unity Catalog Credentials
databricks_account_id       = "98765432-abcd-ef01-2345-6789abcdef01"
databricks_client_id        = "sp-mosaic-terraform-deployer@mosaic-prod"
# databricks_client_secret set via TF_VAR_databricks_client_secret

# Compliance & Lifecycle Policies
medallion_tiers            = ["bronze-raw", "silver-cleansed", "gold-curated"]
hipaa_audit_retention_days = 2555
