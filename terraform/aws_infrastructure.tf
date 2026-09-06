# --------------------------------------------------------------------------------------------------
# AWS INFRASTRUCTURE: CUSTOMER-MANAGED E-VPC, S3 MEDALLION STORAGE & KMS ENCRYPTION
# Mosaic Healthcare Multi-Cloud Production Platform
# --------------------------------------------------------------------------------------------------

# --- KMS Customer Managed Key for S3 & State Encryption ---
resource "aws_kms_key" "mosaic_healthcare_kms" {
  description             = "HIPAA-compliant KMS key for Mosaic Healthcare S3 Medallion storage"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = {
    Name        = "${var.organization_prefix}-healthcare-kms-${var.environment}"
    Compliance  = "HIPAA-KMS-CMK"
    Environment = var.environment
  }
}

resource "aws_kms_alias" "mosaic_healthcare_kms_alias" {
  name          = "alias/${var.organization_prefix}-healthcare-kms-${var.environment}"
  target_key_id = aws_kms_key.mosaic_healthcare_kms.key_id
}

# --- AWS Customer-Managed E-VPC for Databricks Compute ---
resource "aws_vpc" "databricks_evpc" {
  cidr_block           = var.aws_vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.organization_prefix}-databricks-evpc-${var.environment}"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# --- Private Subnets for Databricks Driver & Worker Nodes ---
resource "aws_subnet" "private_subnets" {
  count             = length(var.aws_private_subnets)
  vpc_id            = aws_vpc.databricks_evpc.id
  cidr_block        = var.aws_private_subnets[count.index]
  availability_zone = "${var.aws_region}${count.index == 0 ? "a" : "b"}"

  tags = {
    Name        = "${var.organization_prefix}-databricks-private-subnet-${count.index + 1}-${var.environment}"
    Tier        = "Private-Compute"
    Environment = var.environment
  }
}

# --- S3 Medallion Lakehouse Buckets (Bronze, Silver, Gold, Audit) ---
resource "aws_s3_bucket" "medallion_buckets" {
  for_each      = toset(concat(var.medallion_tiers, ["audit-logs"]))
  bucket        = "${var.organization_prefix}-${each.key}-${var.environment}-${var.aws_region}"
  force_destroy = false

  tags = {
    Name        = "${var.organization_prefix}-${each.key}-${var.environment}"
    Tier        = each.key
    Compliance  = "HIPAA-HITRUST-Encrypted"
    Environment = var.environment
  }
}

# --- S3 Server-Side KMS Encryption Enforcement ---
resource "aws_s3_bucket_server_side_encryption_configuration" "medallion_encryption" {
  for_each = aws_s3_bucket.medallion_buckets

  bucket = each.value.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.mosaic_healthcare_kms.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

# --- S3 Versioning for Disaster Recovery & Audit Immutability ---
resource "aws_s3_bucket_versioning" "medallion_versioning" {
  for_each = aws_s3_bucket.medallion_buckets

  bucket = each.value.id
  versioning_configuration {
    status = "Enabled"
  }
}

# --- S3 Strict Public Access Block (4/4 Zero-Trust Lockdown) ---
resource "aws_s3_bucket_public_access_block" "medallion_public_block" {
  for_each = aws_s3_bucket.medallion_buckets

  bucket = each.value.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- S3 Lifecycle Rule for HIPAA 7-Year (2555 Days) Audit Retention ---
resource "aws_s3_bucket_lifecycle_configuration" "hipaa_audit_lifecycle" {
  bucket = aws_s3_bucket.medallion_buckets["audit-logs"].id

  rule {
    id     = "hipaa-7yr-retention"
    status = "Enabled"

    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 365
      storage_class = "GLACIER"
    }

    expiration {
      days = var.hipaa_audit_retention_days
    }
  }
}

# --- IAM Cross-Account Role for Databricks Unity Catalog ---
resource "aws_iam_role" "databricks_unity_catalog_role" {
  name = "${var.organization_prefix}-databricks-uc-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::414351767826:root" # Official Databricks AWS Account
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.databricks_account_id
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.organization_prefix}-databricks-uc-role"
    Environment = var.environment
  }
}

resource "aws_iam_policy" "databricks_s3_access_policy" {
  name        = "${var.organization_prefix}-databricks-s3-access-${var.environment}"
  description = "Allows Databricks Unity Catalog to manage S3 Medallion storage tiers"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = flatten([
          for b in aws_s3_bucket.medallion_buckets : [
            b.arn,
            "${b.arn}/*"
          ]
        ])
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Resource = [aws_kms_key.mosaic_healthcare_kms.arn]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "databricks_s3_attach" {
  role       = aws_iam_role.databricks_unity_catalog_role.name
  policy_arn = aws_iam_policy.databricks_s3_access_policy.arn
}
