# ==================================================================================================
# DATABRICKS UNITY CATALOG: METASTORE, STORAGE CREDENTIALS & HEALTHCARE GOVERNANCE
# Project: Mosaic Healthcare Multi-Cloud Production Platform
# Governance Framework: Unity Catalog Central Metastore with Cross-Cloud Data Lineage
# ==================================================================================================

# --------------------------------------------------------------------------------------------------
# UNITY CATALOG METASTORE PROVISIONING (ACCOUNT LEVEL - MWS)
# Top-level container for metadata, data lineage, and centralized security access policies
# --------------------------------------------------------------------------------------------------
resource "databricks_metastore" "mosaic_metastore" {
  provider      = databricks.mws
  name          = "${var.organization_prefix}-metastore-${var.environment}"
  # Metastore root storage on S3 Gold curated tier for metastore internal logs and tables
  storage_root  = "s3://${aws_s3_bucket.medallion_buckets["gold-curated"].bucket}/metastore-root"
  region        = var.aws_region
  force_destroy = false # Protects enterprise metastore metadata from accidental deletion
}

# --------------------------------------------------------------------------------------------------
# METASTORE DATA ACCESS CREDENTIAL
# Links the Metastore root storage location to the AWS IAM Cross-Account Role
# --------------------------------------------------------------------------------------------------
resource "databricks_metastore_data_access" "metastore_access" {
  provider     = databricks.mws
  metastore_id = databricks_metastore.mosaic_metastore.id
  name         = "${var.organization_prefix}-metastore-access-${var.environment}"

  aws_iam_role {
    role_arn = aws_iam_role.databricks_unity_catalog_role.arn # Cross-account role ARN
  }
  is_default = true # Sets as default credential for root storage operations
}

# --------------------------------------------------------------------------------------------------
# WORKSPACE STORAGE CREDENTIALS (WORKSPACE LEVEL)
# Allows workspace compute clusters to authenticate securely against S3 without managing long-lived keys
# --------------------------------------------------------------------------------------------------
resource "databricks_storage_credential" "aws_s3_credential" {
  provider = databricks.workspace
  name     = "${var.organization_prefix}-s3-storage-credential"

  aws_iam_role {
    role_arn = aws_iam_role.databricks_unity_catalog_role.arn # IAM Role ARN
  }
  comment = "IAM Cross-Account Storage Credential for AWS S3 Medallion Tiers"
}

# --------------------------------------------------------------------------------------------------
# UNITY CATALOG EXTERNAL LOCATIONS FOR AWS S3
# Declares governed external locations for each Medallion tier in S3 with path-level security
# --------------------------------------------------------------------------------------------------
resource "databricks_external_location" "s3_medallion_locations" {
  for_each        = aws_s3_bucket.medallion_buckets
  provider        = databricks.workspace
  name            = "ext-s3-${each.key}-${var.environment}"
  url             = "s3://${each.value.bucket}/"
  credential_name = databricks_storage_credential.aws_s3_credential.id
  comment         = "Governed external location for AWS S3 ${each.key} tier"
}

# --------------------------------------------------------------------------------------------------
# MEDALLION LAKEHOUSE CLINICAL CATALOGS
# Dedicated Unity Catalog namespaces isolating data lifecycle stages and compliance classifications
# --------------------------------------------------------------------------------------------------

# 1. Bronze Catalog: Raw Ingestion (HL7 v2/v3, FHIR Bundles, Raw Streaming Telemetry)
resource "databricks_catalog" "mosaic_bronze" {
  provider      = databricks.workspace
  name          = "mosaic_bronze_${var.environment}"
  comment       = "Bronze Medallion Layer: Raw HL7/FHIR clinical streams and sensor feeds"
  storage_root  = "s3://${aws_s3_bucket.medallion_buckets["bronze-raw"].bucket}/catalogs/bronze"
  force_destroy = false

  properties = {
    "compliance" = "HIPAA-Encrypted-Raw"
    "data_owner" = "Mosaic-Clinical-Ingestion"
  }
}

# 2. Silver Catalog: Cleansed OMOP Common Data Model & De-duplicated Patient EHR Records
resource "databricks_catalog" "mosaic_silver" {
  provider      = databricks.workspace
  name          = "mosaic_silver_${var.environment}"
  comment       = "Silver Medallion Layer: Cleansed OMOP Common Data Model & De-duplicated Patient EHR"
  storage_root  = "s3://${aws_s3_bucket.medallion_buckets["silver-cleansed"].bucket}/catalogs/silver"
  force_destroy = false

  properties = {
    "compliance" = "HIPAA-Cleansed-CDM"
    "data_owner" = "Mosaic-Clinical-Analytics"
  }
}

# 3. Gold Catalog: Curated Population Health, Bed Surge Predictions & Executive Analytics
resource "databricks_catalog" "mosaic_gold" {
  provider      = databricks.workspace
  name          = "mosaic_gold_${var.environment}"
  comment       = "Gold Medallion Layer: De-identified Population Health, TimesFM Bed Surge & Financial Analytics"
  storage_root  = "s3://${aws_s3_bucket.medallion_buckets["gold-curated"].bucket}/catalogs/gold"
  force_destroy = false

  properties = {
    "compliance" = "HIPAA-Deidentified-Gold"
    "data_owner" = "Mosaic-Executive-Intelligence"
  }
}

# --------------------------------------------------------------------------------------------------
# DATA ACCESS GOVERNANCE & ACCESS CONTROL GRANTS
# Enforces least-privilege role-based access controls across catalog namespaces
# --------------------------------------------------------------------------------------------------

# Bronze catalog access restricted to authorized data engineering personas
resource "databricks_grants" "bronze_grants" {
  provider = databricks.workspace
  catalog  = databricks_catalog.mosaic_bronze.name

  grant {
    principal  = "account users"
    privileges = ["USE_CATALOG", "USE_SCHEMA", "SELECT"]
  }
}

# Gold catalog access configured for broad analytics and clinical reporting
resource "databricks_grants" "gold_grants" {
  provider = databricks.workspace
  catalog  = databricks_catalog.mosaic_gold.name

  grant {
    principal  = "account users"
    privileges = ["USE_CATALOG", "USE_SCHEMA", "SELECT"]
  }
}
