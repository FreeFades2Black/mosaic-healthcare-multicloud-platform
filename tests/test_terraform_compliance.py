"""
Mosaic Healthcare Multi-Cloud Platform
Infrastructure as Code & Compliance Test Suite (tests/test_terraform_compliance.py)
"""

import pytest
import re
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
TERRAFORM_DIR = PROJECT_ROOT / "terraform"
POLICIES_DIR = PROJECT_ROOT / "policies" / "opa"


def test_terraform_files_exist():
    """Verify all required production Terraform files are present."""
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
        assert filepath.exists(), f"Missing required file: {filepath}"


def test_remote_state_backend_configuration():
    """Verify S3 remote state backend uses DynamoDB locking and KMS encryption."""
    backend_file = TERRAFORM_DIR / "backend.tf"
    content = backend_file.read_text(encoding="utf-8")

    assert 'backend "s3"' in content
    assert 'dynamodb_table = "mosaic-healthcare-tflocks-prod"' in content
    assert "encrypt        = true" in content
    assert "kms_key_id" in content


def test_hipaa_retention_and_security_standards():
    """Verify 7-year (2555 days) audit retention and HIPAA standards in variables."""
    variables_file = TERRAFORM_DIR / "variables.tf"
    content = variables_file.read_text(encoding="utf-8")

    assert "hipaa_audit_retention_days" in content
    assert "2555" in content
    assert "mosaic_healthcare_kms" in (TERRAFORM_DIR / "aws_infrastructure.tf").read_text(encoding="utf-8")


def test_aws_s3_zero_trust_public_access_blocks():
    """Verify all S3 buckets enforce 4/4 strict public access blocking."""
    aws_file = TERRAFORM_DIR / "aws_infrastructure.tf"
    content = aws_file.read_text(encoding="utf-8")

    assert "block_public_acls       = true" in content
    assert "block_public_policy     = true" in content
    assert "ignore_public_acls      = true" in content
    assert "restrict_public_buckets = true" in content


def test_azure_vnet_injection_and_adls_hns():
    """Verify Azure VNet Injection subnets and ADLS Gen2 Hierarchical Namespace."""
    azure_file = TERRAFORM_DIR / "azure_infrastructure.tf"
    content = azure_file.read_text(encoding="utf-8")

    assert "host_subnet" in content
    assert "container_subnet" in content
    assert "is_hns_enabled           = true" in content
    assert 'min_tls_version          = "TLS1_2"' in content


def test_databricks_unity_catalog_medallion_tiers():
    """Verify Databricks Unity Catalog defines Bronze, Silver, and Gold catalogs."""
    uc_file = TERRAFORM_DIR / "databricks_unity_catalog.tf"
    content = uc_file.read_text(encoding="utf-8")

    assert "databricks_metastore" in content
    assert "mosaic_bronze" in content
    assert "mosaic_silver" in content
    assert "mosaic_gold" in content


def test_opa_hipaa_rego_policy_integrity():
    """Verify OPA Rego policy file exists and has correct rules."""
    rego_file = POLICIES_DIR / "hipaa_compliance.rego"
    assert rego_file.exists()
    content = rego_file.read_text(encoding="utf-8")
    assert "package terraform.hipaa" in content
    assert "aws_s3_bucket_public_access_block" in content
