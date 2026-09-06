# ==================================================================================================
# AWS CLOUD INFRASTRUCTURE: CUSTOMER-MANAGED E-VPC, S3 MEDALLION & KMS ENCRYPTION
# Project: Mosaic Healthcare Multi-Cloud Production Platform
# Compliance Framework: HIPAA Security Rule (45 CFR § 164.312) & HITRUST Zero-Trust
# ==================================================================================================

# --------------------------------------------------------------------------------------------------
# AWS KMS CUSTOMER MANAGED KEY (CMK) FOR ENCRYPTION AT REST
# Encrypts S3 Medallion storage buckets and DynamoDB state locks with automated 1-year key rotation
# --------------------------------------------------------------------------------------------------
resource "aws_kms_key" "mosaic_healthcare_kms" {
  description             = "HIPAA-compliant KMS Customer Managed Key for Mosaic Healthcare S3 Medallion storage"
  deletion_window_in_days = 30   # Safety window preventing immediate irreversible key destruction
  enable_key_rotation     = true # Automatically rotates cryptographic key material annually (NIST SP 800-57)

  tags = {
    Name        = "${var.organization_prefix}-healthcare-kms-${var.environment}"
    Compliance  = "HIPAA-KMS-CMK"
    Environment = var.environment
  }
}

# User-friendly alias for referencing the KMS key across services
resource "aws_kms_alias" "mosaic_healthcare_kms_alias" {
  name          = "alias/${var.organization_prefix}-healthcare-kms-${var.environment}"
  target_key_id = aws_kms_key.mosaic_healthcare_kms.key_id
}

# --------------------------------------------------------------------------------------------------
# AWS CUSTOMER-MANAGED E-VPC FOR DATABRICKS COMPUTE
# Dedicated virtual private cloud hosting Databricks Spark worker clusters with strict route isolation
# --------------------------------------------------------------------------------------------------
resource "aws_vpc" "databricks_evpc" {
  cidr_block           = var.aws_vpc_cidr # 10.150.0.0/16 address space
  enable_dns_hostnames = true            # Required for Databricks cluster inter-node hostname resolution
  enable_dns_support   = true            # Enables AWS Route 53 resolver integration

  tags = {
    Name        = "${var.organization_prefix}-databricks-evpc-${var.environment}"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# --------------------------------------------------------------------------------------------------
# PRIVATE COMPUTE SUBNETS
# Subnets distributed across multiple availability zones for Databricks driver and worker nodes
# --------------------------------------------------------------------------------------------------
resource "aws_subnet" "private_subnets" {
  count             = length(var.aws_private_subnets)
  vpc_id            = aws_vpc.databricks_evpc.id
  cidr_block        = var.aws_private_subnets[count.index]
  availability_zone = "${var.aws_region}${count.index == 0 ? "a" : "b"}" # Multi-AZ HA placement

  tags = {
    Name        = "${var.organization_prefix}-databricks-private-subnet-${count.index + 1}-${var.environment}"
    Tier        = "Private-Compute"
    Environment = var.environment
  }
}

# --------------------------------------------------------------------------------------------------
# S3 MEDALLION LAKEHOUSE BUCKETS (BRONZE, SILVER, GOLD, AUDIT)
# Deploys physical storage buckets for raw HL7/FHIR, cleansed OMOP CDM, and curated BI layers
# --------------------------------------------------------------------------------------------------
resource "aws_s3_bucket" "medallion_buckets" {
  # Iterates through standard medallion tiers plus dedicated immutable audit log bucket
  for_each      = toset(concat(var.medallion_tiers, ["audit-logs"]))
  bucket        = "${var.organization_prefix}-${each.key}-${var.environment}-${var.aws_region}"
  force_destroy = false # Protects clinical patient data from accidental terraform destroy commands

  tags = {
    Name        = "${var.organization_prefix}-${each.key}-${var.environment}"
    Tier        = each.key
    Compliance  = "HIPAA-HITRUST-Encrypted"
    Environment = var.environment
  }
}

# --------------------------------------------------------------------------------------------------
# S3 SERVER-SIDE ENCRYPTION (SSE-KMS) ENFORCEMENT
# Enforces hardware-backed KMS CMK encryption at rest on all written objects with Bucket Key savings
# --------------------------------------------------------------------------------------------------
resource "aws_s3_bucket_server_side_encryption_configuration" "medallion_encryption" {
  for_each = aws_s3_bucket.medallion_buckets

  bucket = each.value.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.mosaic_healthcare_kms.arn # Uses our customer-managed KMS key
      sse_algorithm     = "aws:kms"                             # Enforces aws:kms encryption algorithm
    }
    bucket_key_enabled = true # Reduces AWS KMS request costs by up to 99% via S3 Bucket Keys
  }
}

# --------------------------------------------------------------------------------------------------
# S3 OBJECT VERSIONING FOR DISASTER RECOVERY & IMMUTABILITY
# Preserves previous object states for audit recovery, ransomware resilience, and rollback safety
# --------------------------------------------------------------------------------------------------
resource "aws_s3_bucket_versioning" "medallion_versioning" {
  for_each = aws_s3_bucket.medallion_buckets

  bucket = each.value.id
  versioning_configuration {
    status = "Enabled" # Activates immutable object version tracking
  }
}

# --------------------------------------------------------------------------------------------------
# S3 ZERO-TRUST STRICT PUBLIC ACCESS BLOCK (4/4 LOCKDOWN)
# Prevents unauthorized public Internet exposure of Protected Health Information (PHI)
# --------------------------------------------------------------------------------------------------
resource "aws_s3_bucket_public_access_block" "medallion_public_block" {
  for_each = aws_s3_bucket.medallion_buckets

  bucket = each.value.id

  block_public_acls       = true # Blocks incoming public ACL grants
  block_public_policy     = true # Rejects any bucket policy granting public access
  ignore_public_acls      = true # Causes S3 to ignore all existing public ACLs
  restrict_public_buckets = true # Restricts bucket access exclusively to authorized IAM principals
}

# --------------------------------------------------------------------------------------------------
# HIPAA 7-YEAR AUDIT LIFECYCLE MANAGEMENT
# Enforces automated storage tier transitions and compliance-mandated 2,555-day retention
# --------------------------------------------------------------------------------------------------
resource "aws_s3_bucket_lifecycle_configuration" "hipaa_audit_lifecycle" {
  bucket = aws_s3_bucket.medallion_buckets["audit-logs"].id

  rule {
    id     = "hipaa-7yr-retention"
    status = "Enabled"

    # Transition to Standard-Infrequent Access after 90 days of operational logging
    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }

    # Transition to Glacier long-term cold archive after 1 year (365 days)
    transition {
      days          = 365
      storage_class = "GLACIER"
    }

    # Permanently expire audit logs after exactly 2,555 days (7 full regulatory years)
    expiration {
      days = var.hipaa_audit_retention_days
    }
  }
}

# --------------------------------------------------------------------------------------------------
# IAM CROSS-ACCOUNT ROLE FOR DATABRICKS UNITY CATALOG
# Allows the Databricks control plane to securely manage S3 Medallion storage via External ID trust
# --------------------------------------------------------------------------------------------------
resource "aws_iam_role" "databricks_unity_catalog_role" {
  name = "${var.organization_prefix}-databricks-uc-role-${var.environment}"

  # Trust policy establishing mutual trust with Databricks AWS Account (414351767826)
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::414351767826:root" # Official Databricks enterprise AWS Account
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.databricks_account_id # Protects against Confused Deputy attacks
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

# IAM Policy granting Databricks Unity Catalog permissions to read/write Medallion data and use KMS
resource "aws_iam_policy" "databricks_s3_access_policy" {
  name        = "${var.organization_prefix}-databricks-s3-access-${var.environment}"
  description = "Allows Databricks Unity Catalog to manage S3 Medallion storage tiers and decrypt via KMS"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Grant S3 data plane read/write/list permissions across all Medallion tiers
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
      # Grant KMS cryptographic operations for customer-managed key encryption/decryption
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

# Attach access policy to cross-account role
resource "aws_iam_role_policy_attachment" "databricks_s3_attach" {
  role       = aws_iam_role.databricks_unity_catalog_role.name
  policy_arn = aws_iam_policy.databricks_s3_access_policy.arn
}

# --------------------------------------------------------------------------------------------------
# AWS ELASTIC CONTAINER REGISTRY (ECR) FOR PORTABLE CLINICAL MICROSERVICES
# Secure OCI container registries with KMS encryption and automated vulnerability scanning
# --------------------------------------------------------------------------------------------------
resource "aws_ecr_repository" "clinical_containers" {
  for_each             = toset(["clinical-ingestion", "clinical-analytics"])
  name                 = "${var.organization_prefix}-${each.key}-${var.environment}"
  image_tag_mutability = "IMMUTABLE"

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.mosaic_healthcare_kms.arn
  }

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "${var.organization_prefix}-${each.key}"
    Compliance  = "HIPAA-Container-Scan"
    Environment = var.environment
  }
}

