package terraform.hipaa

# Default deny
default allow = false

# Allow if all critical HIPAA controls pass
allow {
    count(violation) == 0
}

# Rule 1: S3 Public Access Block must be strictly enabled
violation[sprintf("S3 Bucket '%v' must have strict Public Access Block enabled", [r.address])] {
    r := input.resource_changes[_]
    r.type == "aws_s3_bucket_public_access_block"
    not r.change.after.block_public_acls == true
}

violation[sprintf("S3 Bucket '%v' must restrict public buckets", [r.address])] {
    r := input.resource_changes[_]
    r.type == "aws_s3_bucket_public_access_block"
    not r.change.after.restrict_public_buckets == true
}

# Rule 2: S3 Server-Side KMS Encryption must use Customer Managed Keys
violation[sprintf("S3 Bucket '%v' encryption must use aws:kms algorithm", [r.address])] {
    r := input.resource_changes[_]
    r.type == "aws_s3_bucket_server_side_encryption_configuration"
    rule := r.change.after.rule[_]
    apply := rule.apply_server_side_encryption_by_default[_]
    apply.sse_algorithm != "aws:kms"
}

# Rule 3: Versioning must be enabled for disaster recovery
violation[sprintf("S3 Bucket '%v' must have versioning enabled", [r.address])] {
    r := input.resource_changes[_]
    r.type == "aws_s3_bucket_versioning"
    conf := r.change.after.versioning_configuration[_]
    conf.status != "Enabled"
}

# Rule 4: ADLS Gen2 minimum TLS version must be TLS1_2
violation[sprintf("Azure Storage Account '%v' must enforce TLS 1.2 or higher", [r.address])] {
    r := input.resource_changes[_]
    r.type == "azurerm_storage_account"
    r.change.after.min_tls_version != "TLS1_2"
}
