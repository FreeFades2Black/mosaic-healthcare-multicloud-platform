# 🏥 Mosaic Healthcare Multi-Cloud Platform

[![Multi-Cloud Architecture](https://img.shields.io/badge/Architecture-AWS%20%2B%20Azure%20%2B%20Databricks-blue?style=for-the-badge&logo=databricks&logoColor=white)](https://github.com/FreeFades2Black/mosaic-healthcare-multicloud-platform)
[![Compliance](https://img.shields.io/badge/Compliance-HIPAA%20%7C%20HITRUST-emerald?style=for-the-badge&logo=shield&logoColor=white)](https://github.com/FreeFades2Black/mosaic-healthcare-multicloud-platform)
[![Terraform](https://img.shields.io/badge/IaC-Terraform%20v1.6%2B-purple?style=for-the-badge&logo=terraform&logoColor=white)](https://github.com/FreeFades2Black/mosaic-healthcare-multicloud-platform)
[![Unity Catalog](https://img.shields.io/badge/Governance-Unity%20Catalog-E25A1C?style=for-the-badge&logo=apachespark&logoColor=white)](https://github.com/FreeFades2Black/mosaic-healthcare-multicloud-platform)
[![Docker](https://img.shields.io/badge/Containers-Multi--Stage%20Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)](https://github.com/FreeFades2Black/mosaic-healthcare-multicloud-platform)

---

## 🏛️ Enterprise Multi-Cloud Architecture Overview

The **Mosaic Healthcare Multi-Cloud Platform** provides a production-grade, HIPAA/HITRUST-compliant Infrastructure-as-Code (IaC) foundation spanning **Amazon Web Services (AWS)**, **Microsoft Azure**, and **Databricks Unity Catalog**:

```
                    ┌──────────────────────────────────────────────┐
                    │      DATABRICKS UNITY CATALOG METASTORE      │
                    │   Central Multi-Cloud Governance & Lineage   │
                    └──────────────────────┬───────────────────────┘
                                           │
                 ┌─────────────────────────┴─────────────────────────┐
                 ▼                                                   ▼
  ┌──────────────────────────────┐                    ┌──────────────────────────────┐
  │   AMAZON WEB SERVICES (AWS)  │                    │     MICROSOFT AZURE CLOUD    │
  │ • Customer-Managed E-VPC     │                    │ • VNet Injection (Delegated) │
  │ • S3 Medallion (Bronze/Silv) │                    │ • ADLS Gen2 Hierarchical DFS │
  │ • AWS KMS CMK Encryption     │                    │ • Azure Key Vault CMK        │
  │ • 7-Year HIPAA Object Lock   │                    │ • TLS 1.2+ Enforced DFS      │
  └──────────────────────────────┘                    └──────────────────────────────┘
```

---

## 🔒 HIPAA & Zero-Trust Security Controls

1. **S3 Server-Side KMS Encryption (SSE-KMS):** All S3 Medallion buckets use Customer Managed Keys (`aws_kms_key.mosaic_healthcare_kms`) with automatic key rotation.
2. **Strict Public Access Block:** 4/4 zero-trust lockdown (`block_public_acls`, `block_public_policy`, `ignore_public_acls`, `restrict_public_buckets`).
3. **7-Year Audit Retention:** S3 Lifecycle configuration enforces a 2,555-day (7-year) retention schedule with automatic transitions to `STANDARD_IA` (90 days) and `GLACIER` (365 days).
4. **Azure VNet Injection:** Private subnets delegated to `Microsoft.Databricks/workspaces` for isolated host (driver) and container (worker) compute.
5. **ADLS Gen2 Hierarchical Storage:** Multi-container Medallion layout with Geo-Redundant Storage (GRS) and private VNet endpoint routing.

---

## 📦 Medallion Lakehouse Data Tiering

| Tier | Catalog / Bucket | Storage Layer | Data Classification |
| :--- | :--- | :--- | :--- |
| **Bronze** | `mosaic_bronze_prod` | AWS S3 / Azure ADLS | Raw streaming HL7, FHIR, and EHR sensor payloads |
| **Silver** | `mosaic_silver_prod` | AWS S3 / Azure ADLS | Cleansed OMOP CDM, patient linkage, normalized encounters |
| **Gold** | `mosaic_gold_prod` | AWS S3 / Azure ADLS | De-identified clinical outcomes, bed surge, executive KPIs |
| **Audit** | `audit-logs` | AWS S3 (KMS Encrypted) | 7-year immutable CloudTrail, VPC Flow, and access audit logs |

---

## 🚀 Quickstart & Execution

```bash
# 1. Clone repository
git clone https://github.com/FreeFades2Black/mosaic-healthcare-multicloud-platform.git
cd mosaic-healthcare-multicloud-platform

# 2. Run unit and compliance test suite
python -m pytest tests/ -v

# 3. Initialize remote S3 backend with DynamoDB lock table
cd terraform
terraform init \
  -backend-config="bucket=mosaic-healthcare-tfstate-prod-useast1" \
  -backend-config="dynamodb_table=mosaic-healthcare-tflocks-prod"

# 4. Validate Terraform syntax
terraform validate

# 5. Execute dry-run plan
terraform plan -var-file="terraform.tfvars" -out="mosaic_prod.tfplan"
```

---

## 🐳 Docker Containerization

Run the compliance and Terraform validation suite in an isolated container:

```bash
docker compose up --build
```
