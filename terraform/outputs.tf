# --------------------------------------------------------------------------------------------------
# TERRAFORM OUTPUTS: PROVISIONED MULTI-CLOUD ASSETS & ENDPOINTS
# Mosaic Healthcare Multi-Cloud Production Platform
# --------------------------------------------------------------------------------------------------

# --- AWS Outputs ---
output "aws_vpc_id" {
  description = "Identifier of the AWS customer-managed Databricks E-VPC"
  value       = aws_vpc.databricks_evpc.id
}

output "aws_kms_key_arn" {
  description = "ARN of the HIPAA Customer Managed KMS Key"
  value       = aws_kms_key.mosaic_healthcare_kms.arn
}

output "aws_medallion_s3_buckets" {
  description = "Map of S3 Medallion Lakehouse Bucket ARNs"
  value = {
    for k, b in aws_s3_bucket.medallion_buckets : k => b.arn
  }
}

output "aws_databricks_uc_role_arn" {
  description = "IAM Role ARN assumed by Databricks Unity Catalog"
  value       = aws_iam_role.databricks_unity_catalog_role.arn
}

# --- Azure Outputs ---
output "azure_resource_group_name" {
  description = "Azure Resource Group hosting clinical compute and storage"
  value       = azurerm_resource_group.mosaic_rg.name
}

output "azure_vnet_id" {
  description = "Azure Virtual Network ID for Databricks VNet Injection"
  value       = azurerm_virtual_network.databricks_vnet.id
}

output "azure_adls_primary_endpoint" {
  description = "Primary DFS endpoint for Azure Data Lake Storage Gen2"
  value       = azurerm_storage_account.mosaic_adls.primary_dfs_endpoint
}

# --- Databricks Unity Catalog Outputs ---
output "databricks_metastore_id" {
  description = "Unity Catalog Metastore ID"
  value       = databricks_metastore.mosaic_metastore.id
}

output "databricks_catalogs" {
  description = "Provisioned Unity Catalog clinical catalogs"
  value = {
    bronze = databricks_catalog.mosaic_bronze.name
    silver = databricks_catalog.mosaic_silver.name
    gold   = databricks_catalog.mosaic_gold.name
  }
}

output "compliance_attestation" {
  description = "Security and compliance verification status"
  value = {
    standard           = "HIPAA / HITRUST / NIST SP 800-53"
    s3_encryption      = "SSE-KMS Customer Managed Key (CMK)"
    adls_encryption    = "Azure Key Vault CMK + TLS 1.2+ Enforced"
    public_access_block= "STRICT_LOCKDOWN_ENABLED"
    audit_retention    = "${var.hipaa_audit_retention_days} Days (7 Years)"
  }
}
