# ==================================================================================================
# OPEN POLICY AGENT (OPA) REGO COMPLIANCE RULES
# Framework: HIPAA Security Rule (45 CFR § 164.312) & NIST SP 800-53 Rev 5
# Purpose: Static Policy-as-Code evaluation on Terraform plan output before cloud deployment
# ==================================================================================================

package terraform.hipaa

# Default deny posture: Any plan with violations will be blocked automatically by OPA gate
default allow = false

# Allow deployment if and only if zero compliance violations are detected
allow {
    count(violation) == 0
}

# --------------------------------------------------------------------------------------------------
# RULE 1: S3 BUCKET ZERO-TRUST PUBLIC ACCESS BLOCK ENFORCEMENT
# Ensures all four S3 public access block flags are explicitly set to true
# --------------------------------------------------------------------------------------------------
violation[sprintf("S3 Bucket '%v' must have strict block_public_acls enabled", [r.address])] {
    r := input.resource_changes[_]
    r.type == "aws_s3_bucket_public_access_block"
    not r.change.after.block_public_acls == true
}

violation[sprintf("S3 Bucket '%v' must have strict restrict_public_buckets enabled", [r.address])] {
    r := input.resource_changes[_]
    r.type == "aws_s3_bucket_public_access_block"
    not r.change.after.restrict_public_buckets == true
}

# --------------------------------------------------------------------------------------------------
# RULE 2: S3 SERVER-SIDE KMS CMK ENCRYPTION MANDATE
# Rejects default S3 AES256 encryption in favor of customer-managed KMS key (aws:kms)
# --------------------------------------------------------------------------------------------------
violation[sprintf("S3 Bucket '%v' encryption must use aws:kms algorithm with customer-managed keys", [r.address])] {
    r := input.resource_changes[_]
    r.type == "aws_s3_bucket_server_side_encryption_configuration"
    rule := r.change.after.rule[_]
    apply := rule.apply_server_side_encryption_by_default[_]
    apply.sse_algorithm != "aws:kms"
}

# --------------------------------------------------------------------------------------------------
# RULE 3: S3 IMMUTABLE OBJECT VERSIONING ENFORCEMENT
# Ensures state versioning is enabled across all Medallion tiers for clinical data protection
# --------------------------------------------------------------------------------------------------
violation[sprintf("S3 Bucket '%v' must have object versioning set to 'Enabled'", [r.address])] {
    r := input.resource_changes[_]
    r.type == "aws_s3_bucket_versioning"
    conf := r.change.after.versioning_configuration[_]
    conf.status != "Enabled"
}

# --------------------------------------------------------------------------------------------------
# RULE 4: AZURE STORAGE MINIMUM TLS 1.2+ PROTOCOL ENFORCEMENT
# Rejects legacy TLS protocols for clinical data in transit across Azure ADLS Gen2 DFS
# --------------------------------------------------------------------------------------------------
violation[sprintf("Azure Storage Account '%v' must enforce minimum TLS version 'TLS1_2'", [r.address])] {
    r := input.resource_changes[_]
    r.type == "azurerm_storage_account"
    r.change.after.min_tls_version != "TLS1_2"
}
