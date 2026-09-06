"""
==================================================================================================
MOSAIC HEALTHCARE MULTI-CLOUD PLATFORM
Infrastructure as Code & Compliance Test Suite (tests/test_terraform_compliance.py)
Automated verification of Terraform architecture, zero-trust controls, and HIPAA compliance rules.
==================================================================================================
"""

import pytest
import re
from pathlib import Path

# Resolve project root and subdirectories dynamically
PROJECT_ROOT = Path(__file__).resolve().parent.parent
TERRAFORM_DIR = PROJECT_ROOT / "terraform"
POLICIES_DIR = PROJECT_ROOT / "policies" / "opa"


def test_terraform_files_exist():
    """Verify all required production Terraform architecture files exist in the terraform/ directory."""
    required_files = [
        "backend.tf",
        "variables.tf",
        "terraform.tfvars",
        "aws_infrastructure.tf",
        "azure_infrastructure.tf",
        "databricks_unity_catalog.tf",
        "outputs.tf"
    ]
    for filename in required_files:
        filepath = TERRAFORM_DIR / filename
        assert filepath.exists(), f"Missing required architecture file: {filepath}"


def test_remote_state_backend_configuration():
    """Verify S3 remote state backend uses DynamoDB locking, S3 encryption, and KMS key integration."""
    backend_file = TERRAFORM_DIR / "backend.tf"
    content = backend_file.read_text(encoding="utf-8")

    # Ensure S3 backend is explicitly declared
    assert 'backend "s3"' in content, "Missing S3 remote backend declaration"
    # Ensure DynamoDB table is declared for state concurrency locking
    assert 'dynamodb_table = "mosaic-healthcare-tflocks-prod"' in content, "Missing DynamoDB lock table"
    # Ensure server-side encryption is set to true
    assert "encrypt        = true" in content, "Server-side encryption must be enabled for state"
    # Ensure KMS key ID is specified
    assert "kms_key_id" in content, "Missing KMS key ARN in backend configuration"


def test_hipaa_retention_and_security_standards():
    """Verify 7-year (2555 days) audit retention and HIPAA standards are enforced in variable definitions."""
    variables_file = TERRAFORM_DIR / "variables.tf"
    content = variables_file.read_text(encoding="utf-8")

    # Check for HIPAA audit retention variable
    assert "hipaa_audit_retention_days" in content, "Missing hipaa_audit_retention_days variable"
    assert "2555" in content, "Audit retention must default to 2555 days (7 years)"
    # Verify KMS Customer Managed Key reference in AWS infrastructure
    assert "mosaic_healthcare_kms" in (TERRAFORM_DIR / "aws_infrastructure.tf").read_text(encoding="utf-8")


def test_aws_s3_zero_trust_public_access_blocks():
    """Verify all S3 buckets enforce all 4 strict public access block flags (Zero-Trust)."""
    aws_file = TERRAFORM_DIR / "aws_infrastructure.tf"
    content = aws_file.read_text(encoding="utf-8")

    # Assert all 4 public access block flags are strictly enabled
    assert "block_public_acls       = true" in content, "block_public_acls must be true"
    assert "block_public_policy     = true" in content, "block_public_policy must be true"
    assert "ignore_public_acls      = true" in content, "ignore_public_acls must be true"
    assert "restrict_public_buckets = true" in content, "restrict_public_buckets must be true"


def test_azure_vnet_injection_and_adls_hns():
    """Verify Azure VNet Injection subnets and ADLS Gen2 Hierarchical Namespace (HNS) are configured."""
    azure_file = TERRAFORM_DIR / "azure_infrastructure.tf"
    content = azure_file.read_text(encoding="utf-8")

    # Verify dedicated host and container delegated subnets
    assert "host_subnet" in content, "Missing host_subnet delegation for Databricks driver"
    assert "container_subnet" in content, "Missing container_subnet delegation for Databricks workers"
    # Verify Hierarchical Namespace is enabled for Delta Lake performance
    assert "is_hns_enabled           = true" in content, "ADLS Gen2 HNS must be enabled"
    # Verify minimum TLS protocol version
    assert 'min_tls_version          = "TLS1_2"' in content, "Minimum TLS version must be TLS1_2"


def test_databricks_unity_catalog_medallion_tiers():
    """Verify Databricks Unity Catalog defines Metastore, Storage Credentials, and Medallion catalogs."""
    uc_file = TERRAFORM_DIR / "databricks_unity_catalog.tf"
    content = uc_file.read_text(encoding="utf-8")

    # Verify metastore resource
    assert "databricks_metastore" in content, "Missing databricks_metastore resource"
    # Verify 3 clinical Medallion catalogs
    assert "mosaic_bronze" in content, "Missing mosaic_bronze catalog"
    assert "mosaic_silver" in content, "Missing mosaic_silver catalog"
    assert "mosaic_gold" in content, "Missing mosaic_gold catalog"


def test_opa_hipaa_rego_policy_integrity():
    """Verify OPA Rego policy file exists, defines package terraform.hipaa, and specifies S3 rules."""
    rego_file = POLICIES_DIR / "hipaa_compliance.rego"
    assert rego_file.exists(), f"Missing OPA Rego policy file: {rego_file}"
    content = rego_file.read_text(encoding="utf-8")
    assert "package terraform.hipaa" in content, "Incorrect OPA package namespace"
    assert "aws_s3_bucket_public_access_block" in content, "Missing S3 public access block rule in OPA"


def test_multicloud_container_registries():
    """Verify AWS ECR and Azure ACR container registry resources are declared."""
    aws_content = (TERRAFORM_DIR / "aws_infrastructure.tf").read_text(encoding="utf-8")
    azure_content = (TERRAFORM_DIR / "azure_infrastructure.tf").read_text(encoding="utf-8")

    assert "aws_ecr_repository" in aws_content, "Missing aws_ecr_repository in AWS infrastructure"
    assert "azurerm_container_registry" in azure_content, "Missing azurerm_container_registry in Azure infrastructure"

