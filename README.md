# 🏥 Mosaic Healthcare Multi-Cloud Platform

[![Multi-Cloud Architecture](https://img.shields.io/badge/Architecture-AWS%20%2B%20Azure%20%2B%20Databricks-blue?style=for-the-badge&logo=databricks&logoColor=white)](https://github.com/FreeFades2Black/mosaic-healthcare-multicloud-platform)
[![Compliance](https://img.shields.io/badge/Compliance-HIPAA%20%7C%20HITRUST-emerald?style=for-the-badge&logo=shield&logoColor=white)](https://github.com/FreeFades2Black/mosaic-healthcare-multicloud-platform)
[![Terraform](https://img.shields.io/badge/IaC-Terraform%20v1.6%2B-purple?style=for-the-badge&logo=terraform&logoColor=white)](https://github.com/FreeFades2Black/mosaic-healthcare-multicloud-platform)
[![Unity Catalog](https://img.shields.io/badge/Governance-Unity%20Catalog-E25A1C?style=for-the-badge&logo=apachespark&logoColor=white)](https://github.com/FreeFades2Black/mosaic-healthcare-multicloud-platform)
[![Docker](https://img.shields.io/badge/Containers-Multi--Stage%20Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)](https://github.com/FreeFades2Black/mosaic-healthcare-multicloud-platform)

---

## 🏛️ Executive Enterprise Architecture Overview

The **Mosaic Healthcare Multi-Cloud Platform** is an enterprise-grade, HIPAA/HITRUST-compliant Infrastructure-as-Code (IaC) foundation engineered to unify **Amazon Web Services (AWS)** compute/storage, **Microsoft Azure** clinical networking, and **Databricks Unity Catalog** into a singular, highly governed healthcare data lakehouse:

```
                            ┌──────────────────────────────────────────────┐
                            │      DATABRICKS UNITY CATALOG METASTORE      │
                            │   Central Multi-Cloud Governance & Lineage   │
                            └──────────────────────┬───────────────────────┘
                                                   │
                 ┌─────────────────────────────────┴─────────────────────────────────┐
                 ▼                                                                   ▼
  ┌──────────────────────────────┐                                    ┌──────────────────────────────┐
  │   AMAZON WEB SERVICES (AWS)  │                                    │     MICROSOFT AZURE CLOUD    │
  │ • Customer-Managed E-VPC     │                                    │ • VNet Injection (Delegated) │
  │ • S3 Medallion (Bronze/Silv) │                                    │ • ADLS Gen2 Hierarchical DFS │
  │ • AWS KMS CMK Encryption     │                                    │ • Azure Key Vault CMK        │
  │ • 7-Year HIPAA Object Lock   │                                    │ • TLS 1.2+ Enforced DFS      │
  │ • Strict 4/4 S3 Public Block │                                    │ • NSG Microsegmentation      │
  └──────────────────────────────┘                                    └──────────────────────────────┘
```

---

## 🔒 HIPAA / HITRUST Regulatory Mapping Matrix

Every infrastructure component maps directly to federal healthcare compliance standards:

| Federal Compliance Standard | Technical Control Implemented | Terraform Resource Reference |
| :--- | :--- | :--- |
| **45 CFR § 164.312(a)(2)(iv)**<br>*Encryption at Rest* | S3 Server-Side KMS Customer Managed Keys (`aws:kms`) with automatic annual key rotation. | [`aws_kms_key.mosaic_healthcare_kms`](terraform/aws_infrastructure.tf)<br>[`aws_s3_bucket_server_side_encryption_configuration`](terraform/aws_infrastructure.tf) |
| **45 CFR § 164.312(e)(1)**<br>*Encryption in Transit* | TLS 1.2+ protocol enforcement on all Azure ADLS Gen2 DFS endpoints and internal VNet routing. | [`azurerm_storage_account.mosaic_adls`](terraform/azure_infrastructure.tf) |
| **45 CFR § 164.312(b)**<br>*Audit Controls & Lineage* | Databricks Unity Catalog centralized metadata lineage across multi-cloud tables and storage credentials. | [`databricks_metastore`](terraform/databricks_unity_catalog.tf)<br>[`databricks_catalog`](terraform/databricks_unity_catalog.tf) |
| **45 CFR § 164.316(b)(2)(i)**<br>*7-Year Audit Retention* | Immutable S3 Lifecycle transition to Glacier with mandatory 2,555-day (7-year) expiration. | [`aws_s3_bucket_lifecycle_configuration.hipaa_audit_lifecycle`](terraform/aws_infrastructure.tf) |
| **NIST SP 800-53 Rev 5**<br>*Boundary Protection (SC-7)* | Azure Databricks VNet Injection with NSG microsegmentation blocking all public Internet ingress. | [`azurerm_network_security_group.databricks_nsg`](terraform/azure_infrastructure.tf)<br>[`azurerm_subnet.host_subnet`](terraform/azure_infrastructure.tf) |

---

## 📦 Medallion Lakehouse Storage Topology

```
  RAW HL7 / FHIR / EHR FEEDS (Kafka / EventHub)
                      │
                      ▼
  ┌────────────────────────────────────────────────────────┐
  │ 🟫 BRONZE: Raw Immutable Ingestion                     │
  │ • S3 Bucket: mosaic-bronze-prod-useast1                │
  │ • ADLS Gen2: mosaicadlsprod/bronze-raw                 │
  │ • Unity Catalog: mosaic_bronze_prod                    │
  │ • Encryption: AWS KMS CMK / Azure Key Vault            │
  └──────────────────────────┬─────────────────────────────┘
                             │
                             ▼
  ┌────────────────────────────────────────────────────────┐
  │ ⬜ SILVER: Cleansed OMOP Common Data Model (CDM)       │
  │ • S3 Bucket: mosaic-silver-prod-useast1                │
  │ • ADLS Gen2: mosaicadlsprod/silver-cleansed            │
  │ • Unity Catalog: mosaic_silver_prod                    │
  │ • De-duplicated patient records & normalized clinicals │
  └──────────────────────────┬─────────────────────────────┘
                             │
                             ▼
  ┌────────────────────────────────────────────────────────┐
  │ 🟨 GOLD: De-Identified Curated Population Health       │
  │ • S3 Bucket: mosaic-gold-prod-useast1                  │
  │ • ADLS Gen2: mosaicadlsprod/gold-curated               │
  │ • Unity Catalog: mosaic_gold_prod                      │
  │ • Predictive Bed Surge, Capacity & Financial Reporting │
  └────────────────────────────────────────────────────────┘
```

---

## 🛠️ Enterprise Operational Requirements (Day-2 Production Checklist)

To transition this Infrastructure-as-Code foundation into full Fortune 500 hospital network operation, the following enterprise capabilities must be provisioned:

### 1. Enterprise Identity & Access Management (IAM)
* **Single Sign-On (SSO):** Integrate Okta or Azure AD (Entra ID) with Databricks SCIM provisioning for automated user provisioning and de-provisioning.
* **Role-Based Access Control (RBAC):** Map clinical personas (`Clinical_Data_Scientist`, `Biostatistician`, `Audit_Officer`) to Unity Catalog Catalog/Schema/Table grants.
* **AWS IAM Identity Center:** Federate AWS administrative roles via SAML 2.0 with strict MFA mandates.

### 2. GitOps CI/CD Deployment Pipeline
* **OIDC Authentication:** Configure GitHub Actions OIDC trust with AWS and Azure to eliminate long-lived cloud credentials in CI/CD secrets.
* **Automated Plan Review Gate:** Integrate Atlantis, Spacelift, or Terraform Cloud to enforce dual-approval policy reviews before executing `terraform apply`.
* **Static Policy-as-Code Enforcement:** Automated execution of Open Policy Agent (OPA) and Checkov in pull request checks to prevent compliance regressions.

### 3. Security Observability & SIEM Integration
* **Centralized Log Aggregation:** Forward AWS CloudTrail, S3 Access Logs, Azure NSG Flow Logs, and Databricks Audit Logs into a central SIEM (Splunk, Datadog, or AWS Security Lake).
* **Automated Threat Detection:** Enable AWS GuardDuty and Microsoft Defender for Cloud with automated EventBridge / Logic App remediation playbooks.

### 4. Disaster Recovery (DR) & Business Continuity
* **Cross-Region Replication:** Enable S3 Cross-Region Replication (CRR) from `us-east-1` to `us-west-2` for critical Silver and Gold Delta tables.
* **Point-in-Time Recovery (PITR):** Leverage Delta Lake Time Travel and S3 versioning to guarantee RPO < 15 minutes and RTO < 1 hour.
* **Geo-Redundant ADLS:** Utilize Azure GRS replication to protect against regional datacenter outages.

### 5. FinOps & Cost Optimization
* **Auto-Termination Policies:** Enforce 15-minute auto-termination on all Databricks interactive compute clusters.
* **Storage Tiering:** Automated lifecycle transitions from S3 Standard $\rightarrow$ Standard-IA (90 days) $\rightarrow$ Glacier Flexible (365 days) $\rightarrow$ Expiration (2555 days).
* **AWS & Azure Budget Alerts:** Configure automated PagerDuty/Slack notifications at 80% and 100% monthly budget thresholds.

---

## 🚀 Quickstart & Validation

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

Run the compliance and Terraform validation suite in an isolated, non-root container:

```bash
docker compose up --build
```
