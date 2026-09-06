# --------------------------------------------------------------------------------------------------
# DATABRICKS UNITY CATALOG: METASTORE, STORAGE CREDENTIALS & HEALTHCARE DATA GOVERNANCE
# Mosaic Healthcare Multi-Cloud Production Platform
# --------------------------------------------------------------------------------------------------

# --- Unity Catalog Metastore ---
resource "databricks_metastore" "mosaic_metastore" {
  provider      = databricks.mws
  name          = "${var.organization_prefix}-metastore-${var.environment}"
  storage_root  = "s3://${aws_s3_bucket.medallion_buckets["gold-curated"].bucket}/metastore-root"
  region        = var.aws_region
  force_destroy = false
}

# --- Metastore Data Access (Storage Credential for Root) ---
resource "databricks_metastore_data_access" "metastore_access" {
  provider     = databricks.mws
  metastore_id = databricks_metastore.mosaic_metastore.id
  name         = "${var.organization_prefix}-metastore-access-${var.environment}"
  aws_iam_role {
    role_arn = aws_iam_role.databricks_unity_catalog_role.arn
  }
  is_default = true
}

# --- Unity Catalog Storage Credentials ---
resource "databricks_storage_credential" "aws_s3_credential" {
  provider = databricks.workspace
  name     = "${var.organization_prefix}-s3-storage-credential"
  aws_iam_role {
    role_arn = aws_iam_role.databricks_unity_catalog_role.arn
  }
  comment = "IAM Cross-Account Storage Credential for AWS S3 Medallion Tiers"
}

# --- Unity Catalog External Locations for AWS S3 ---
resource "databricks_external_location" "s3_medallion_locations" {
  for_each        = aws_s3_bucket.medallion_buckets
  provider        = databricks.workspace
  name            = "ext-s3-${each.key}-${var.environment}"
  url             = "s3://${each.value.bucket}/"
  credential_name = databricks_storage_credential.aws_s3_credential.id
  comment         = "External location for AWS S3 ${each.key} tier"
}

# --- Unity Catalog Catalogs for Clinical Medallion Architecture ---
# 1. Bronze Catalog: Raw Ingestion (HL7, FHIR, Raw EHR streams)
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

# 2. Silver Catalog: Cleansed OMOP CDM & Standardized Electronic Health Records
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

# 3. Gold Catalog: Curated Population Health, Bed Surge & Executive BI Analytics
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

# --- Healthcare Governance & Access Control Grants ---
resource "databricks_grants" "bronze_grants" {
  provider = databricks.workspace
  catalog  = databricks_catalog.mosaic_bronze.name

  grant {
    principal  = "account users"
    privileges = ["USE_CATALOG", "USE_SCHEMA", "SELECT"]
  }
}

resource "databricks_grants" "gold_grants" {
  provider = databricks.workspace
  catalog  = databricks_catalog.mosaic_gold.name

  grant {
    principal  = "account users"
    privileges = ["USE_CATALOG", "USE_SCHEMA", "SELECT"]
  }
}
