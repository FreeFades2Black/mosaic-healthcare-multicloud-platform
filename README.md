# Mosaic Healthcare Multi-Cloud Platform

[![Multi-Cloud Architecture](https://img.shields.io/badge/Architecture-AWS%20%2B%20Azure%20%2B%20Databricks-blue?style=for-the-badge&logo=databricks&logoColor=white)](https://github.com/FreeFades2Black/mosaic-healthcare-multicloud-platform)
[![Compliance](https://img.shields.io/badge/Compliance-HIPAA%20%7C%20HITRUST-emerald?style=for-the-badge&logo=shield&logoColor=white)](https://github.com/FreeFades2Black/mosaic-healthcare-multicloud-platform)
[![Terraform](https://img.shields.io/badge/IaC-Terraform%20v1.6%2B-purple?style=for-the-badge&logo=terraform&logoColor=white)](https://github.com/FreeFades2Black/mosaic-healthcare-multicloud-platform)
[![Unity Catalog](https://img.shields.io/badge/Governance-Unity%20Catalog-E25A1C?style=for-the-badge&logo=apachespark&logoColor=white)](https://github.com/FreeFades2Black/mosaic-healthcare-multicloud-platform)
[![Docker](https://img.shields.io/badge/Containers-Multi--Stage%20Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)](https://github.com/FreeFades2Black/mosaic-healthcare-multicloud-platform)

---

## Enterprise Multi-Cloud Architecture Overview

The **Mosaic Healthcare Multi-Cloud Platform** provides a HIPAA/HITRUST-aligned Infrastructure-as-Code (IaC) foundation engineered to unify **Amazon Web Services (AWS)** compute and storage, **Microsoft Azure** clinical networking, and **Databricks Unity Catalog** into a governed multi-cloud data lakehouse:

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

## HIPAA and HITRUST Regulatory Mapping Matrix

Infrastructure components map directly to federal healthcare compliance standards:

| Compliance Standard | Technical Control Implemented | Terraform Resource Reference |
| :--- | :--- | :--- |
| **45 CFR § 164.312(a)(2)(iv)**<br>*Encryption at Rest* | S3 Server-Side KMS Customer Managed Keys (`aws:kms`) with automatic annual key rotation. | [`aws_kms_key.mosaic_healthcare_kms`](terraform/aws_infrastructure.tf)<br>[`aws_s3_bucket_server_side_encryption_configuration`](terraform/aws_infrastructure.tf) |
| **45 CFR § 164.312(e)(1)**<br>*Encryption in Transit* | TLS 1.2+ protocol enforcement on all Azure ADLS Gen2 DFS endpoints and internal VNet routing. | [`azurerm_storage_account.mosaic_adls`](terraform/azure_infrastructure.tf) |
| **45 CFR § 164.312(b)**<br>*Audit Controls & Lineage* | Databricks Unity Catalog centralized metadata lineage across multi-cloud tables and storage credentials. | [`databricks_metastore`](terraform/databricks_unity_catalog.tf)<br>[`databricks_catalog`](terraform/databricks_unity_catalog.tf) |
| **45 CFR § 164.316(b)(2)(i)**<br>*7-Year Audit Retention* | Immutable S3 Lifecycle transition to Glacier with mandatory 2,555-day (7-year) expiration. | [`aws_s3_bucket_lifecycle_configuration.hipaa_audit_lifecycle`](terraform/aws_infrastructure.tf) |
| **NIST SP 800-53 Rev 5**<br>*Boundary Protection (SC-7)* | Azure Databricks VNet Injection with NSG microsegmentation blocking public Internet ingress. | [`azurerm_network_security_group.databricks_nsg`](terraform/azure_infrastructure.tf)<br>[`azurerm_subnet.host_subnet`](terraform/azure_infrastructure.tf) |

---

---

## Medallion Lakehouse Storage Topology

```
  RAW HL7 / FHIR / EHR FEEDS (Kafka / EventHub)
                      │
                      ▼
  ┌────────────────────────────────────────────────────────┐
  │ BRONZE: Raw Immutable Ingestion                        │
  │ • S3 Bucket: mosaic-bronze-prod-useast1                │
  │ • ADLS Gen2: mosaicadlsprod/bronze-raw                 │
  │ • Unity Catalog: mosaic_bronze_prod                    │
  │ • Encryption: AWS KMS CMK / Azure Key Vault            │
  └──────────────────────────┬─────────────────────────────┘
                             │
                             ▼
  ┌────────────────────────────────────────────────────────┐
  │ SILVER: Cleansed OMOP Common Data Model (CDM)          │
  │ • S3 Bucket: mosaic-silver-prod-useast1                │
  │ • ADLS Gen2: mosaicadlsprod/silver-cleansed            │
  │ • Unity Catalog: mosaic_silver_prod                    │
  │ • De-duplicated patient records & normalized clinicals │
  └──────────────────────────┬─────────────────────────────┘
                             │
                             ▼
  ┌────────────────────────────────────────────────────────┐
  │ GOLD: De-Identified Curated Population Health          │
  │ • S3 Bucket: mosaic-gold-prod-useast1                  │
  │ • ADLS Gen2: mosaicadlsprod/gold-curated               │
  │ • Unity Catalog: mosaic_gold_prod                      │
  │ • Predictive Bed Surge, Capacity & Financial Reporting │
  └────────────────────────────────────────────────────────┘
```

---

## Operational Requirements (Day-2 Production Checklist)

To operate this multi-cloud infrastructure within a regulated hospital network, the following capabilities are maintained:

### 1. Identity & Access Management (IAM)
* **Single Sign-On (SSO):** Integrate Entra ID / Okta with Databricks SCIM provisioning for automated user lifecycle management.
* **Role-Based Access Control (RBAC):** Map clinical personas (`Clinical_Data_Scientist`, `Biostatistician`, `Audit_Officer`) to Unity Catalog grants.
* **AWS IAM Identity Center:** Federate AWS administrative roles via SAML 2.0 with strict MFA enforcement.

### 2. Deployment Automation & Policy Enforcement
* **OIDC Authentication:** Configure GitHub Actions OIDC trust with AWS and Azure to eliminate long-lived cloud credentials in CI/CD.
* **Automated Plan Review Gate:** Integrate pull request approval policies prior to running Terraform deployments.
* **Policy-as-Code Enforcement:** Automated execution of Open Policy Agent (OPA Rego) and Checkov to detect compliance regressions.

### 3. Security Observability & SIEM Integration
* **Centralized Log Aggregation:** Forward AWS CloudTrail, S3 Access Logs, Azure NSG Flow Logs, and Databricks Audit Logs into a central SIEM.
* **Automated Threat Detection:** Enable AWS GuardDuty and Microsoft Defender for Cloud with automated EventBridge remediation playbooks.

### 4. Disaster Recovery & Business Continuity
* **Cross-Region Replication:** Enable S3 Cross-Region Replication (CRR) from `us-east-1` to `us-west-2` for Silver and Gold Delta tables.
* **Point-in-Time Recovery (PITR):** Leverage Delta Lake Time Travel and S3 versioning to ensure RPO < 15 minutes and RTO < 1 hour.
* **Geo-Redundant ADLS:** Utilize Azure GRS replication to guard against regional datacenter outages.

### 5. FinOps & Cost Optimization
* **Auto-Termination Policies:** Enforce 15-minute auto-termination on all Databricks interactive compute clusters.
* **Storage Tiering:** Automated lifecycle transitions from S3 Standard -> Standard-IA (90 days) -> Glacier Flexible (365 days) -> Expiration (2,555 days).
* **Cloud Budget Alerts:** Configure automated alerting at 80% and 100% monthly budget thresholds.

---

## Multi-Cloud Container Portability & Workload Migration

Containerization decouples clinical business logic, ingestion pipelines, and AI models from cloud-specific proprietary runtimes. Workloads execute interchangeably across AWS, Microsoft Azure, and On-Premises/Edge nodes:

```
                         ┌──────────────────────────────────────────────┐
                         │   GLOBAL ANYCAST DNS / TRAFFIC ORCHESTRATOR   │
                         │      (AWS Route 53 / Azure Front Door)       │
                         └──────────────────────┬───────────────────────┘
                                                │
                 ┌──────────────────────────────┴──────────────────────────────┐
                 ▼                                                             ▼
  ┌──────────────────────────────┐                              ┌──────────────────────────────┐
  │   AMAZON WEB SERVICES (AWS)  │ ◄─────── Active-Active ──────►│     MICROSOFT AZURE CLOUD    │
  │ • AWS ECS / Fargate          │         Workload Shift        │ • Azure Container Apps (ACA) │
  │ • AWS EKS (Spark on K8s)     │                               │ • Azure AKS (Spark on K8s)   │
  │ • Amazon ECR Registry        │                              │ • Azure ACR Registry         │
  │ • S3 Medallion (Bronze/Gold) │                              │ • ADLS Gen2 Hierarchical DFS │
  └──────────────┬───────────────┘                              └──────────────┬───────────────┘
                 │                                                             │
                 └──────────────────────────────┬──────────────────────────────┘
                                                ▼
                         ┌──────────────────────────────────────────────┐
                         │      DATABRICKS UNITY CATALOG METASTORE      │
                         │ Central Multi-Cloud Data Sharing & Governance│
                         └──────────────────────────────────────────────┘
```

### Workload Tier Alignment

| Workload Tier | Component | AWS Container Host | Azure Container Host | Local / Bare-Metal Edge |
| :--- | :--- | :--- | :--- | :--- |
| **Ingestion Edge** | [`clinical_ingestion`](containers/clinical_ingestion/) (HL7/FHIR Ingestion) | **AWS ECS / Fargate** | **Azure Container Apps** | **Docker Compose (Port 8080)** |
| **Analytics & AI** | [`clinical_analytics`](containers/clinical_analytics/) (TimesFM-3 Bed Surge API) | **AWS App Runner / ECS** | **Azure App Service (Linux)**| **Docker Compose (Port 8090)** |
| **Distributed Spark**| Spark Delta Engine (Bronze -> Silver -> Gold) | **Amazon EKS (Fargate)** | **Azure AKS (System Pool)** | **Local PySpark Container** |
| **Compliance Gate** | [`validator`](Dockerfile) (Terraform & OPA Policy Runner) | **AWS CodeBuild / Actions** | **Azure DevOps Pipelines** | **Docker Compose (On-Demand)**|

### Workload Transfer Strategy

1. **Dual Registry Synchronization:** Build once using `docker buildx` and push multi-arch container images (`linux/amd64`, `linux/arm64`) to both **Amazon ECR** and **Azure Container Registry**.
2. **Global Traffic Shifting:** In the event of a regional degradation or pricing shift, global traffic routes dynamically to Azure Container Apps via Weighted DNS and health probes.
3. **Storage Abstraction via Unity Catalog:** Containers interact with the Medallion lakehouse through Unity Catalog Delta Lake APIs, abstracting underlying S3 and ADLS Gen2 storage nuances.

---

## Build Verification & Concrete Test Artifacts

Pipeline integrity, container manifests, and multi-cloud compliance policies are validated via pytest:

```text
============================= test session starts =============================
platform win32 -- Python 3.11.0, pytest-9.1.1, pluggy-1.6.0
rootdir: C:\Users\FreeF\projects\mosaic-healthcare-multicloud-platform
configfile: pytest.ini
testpaths: tests
plugins: anyio-4.14.2
collected 12 items

tests/test_container_workloads.py::test_clinical_ingestion_microservice_health_and_ingestion PASSED [  8%]
tests/test_container_workloads.py::test_clinical_analytics_microservice_health_and_forecasts PASSED [ 16%]
tests/test_container_workloads.py::test_docker_compose_multicloud_manifest_integrity PASSED [ 25%]
tests/test_container_workloads.py::test_kubernetes_manifests_non_root_security PASSED [ 33%]
tests/test_terraform_compliance.py::test_terraform_files_exist PASSED    [ 41%]
tests/test_terraform_compliance.py::test_remote_state_backend_configuration PASSED [ 50%]
tests/test_terraform_compliance.py::test_hipaa_retention_and_security_standards PASSED [ 58%]
tests/test_terraform_compliance.py::test_aws_s3_zero_trust_public_access_blocks PASSED [ 66%]
tests/test_terraform_compliance.py::test_azure_vnet_injection_and_adls_hns PASSED [ 75%]
tests/test_terraform_compliance.py::test_databricks_unity_catalog_medallion_tiers PASSED [ 83%]
tests/test_terraform_compliance.py::test_opa_hipaa_rego_policy_integrity PASSED [ 91%]
tests/test_terraform_compliance.py::test_multicloud_container_registries PASSED [100%]

======================== 12 passed in 0.54s ========================
```

### Verified Multi-Cloud Edge Cases & Engineering Trade-Offs

1. **S3 Object Lock vs. ADLS Gen2 Immutability Policies:**
   - *Challenge:* AWS S3 Compliance Mode prevents object deletion even by root accounts for 2,555 days (HIPAA audit retention). Azure ADLS Gen2 achieves equivalent immutability via time-based legal hold policies.
   - *Trade-off:* Test environments cannot delete test buckets until retention expires unless configured with conditional lifecycle bypass flags during test teardown.
2. **Databricks Unity Catalog Cross-Cloud Identity Federation:**
   - *Challenge:* Authenticating Databricks across both AWS and Azure requires managing both IAM Role trust policies with external ID validation and Azure Managed Identity federated credentials.
   - *Trade-off:* Centralizing metadata in Unity Catalog simplifies SQL governance across data scientists, but requires coordinating IAM role permissions across both cloud providers.
3. **Non-Root Container Security in Read-Only Root Filesystems:**
   - *Challenge:* HIPAA container standards enforce non-root execution (UID 10001). Under AWS Fargate and Kubernetes read-only root filesystems, application log writers fail unless explicit ephemeral volume mounts (`emptyDir` or `/tmp`) are declared.
   - *Resolution:* All container manifests explicitly configure read-only root filesystems with dedicated temporary volume mounts for ephemeral buffers.

---

## Quickstart & Local Docker Execution

```bash
# 1. Clone repository
git clone https://github.com/FreeFades2Black/mosaic-healthcare-multicloud-platform.git
cd mosaic-healthcare-multicloud-platform

# 2. Run complete unit, compliance, and container test suite
python -m pytest tests/ -v

# 3. Launch multi-cloud microservice stack locally in Docker
docker compose -f docker-compose.multicloud.yml up -d

# 4. Ingest sample FHIR patient encounter into containerized Bronze layer
curl -X POST http://localhost:8080/api/v1/ingest/encounter \
  -H "Content-Type: application/json" \
  -d '{"encounter_id":"ENC-101","patient_id_pseudonym":"PAT-99","facility_ccn":"420078","encounter_type":"EMERGENCY"}'

# 5. Query containerized bed surge predictive API
curl http://localhost:8090/api/v1/analytics/bed-surge/summary
```

---

## Governance Portal & Live Telemetry

* **Live Governance Portal:** [https://freefades2black.github.io/mosaic-health-cloud-architecture/](https://freefades2black.github.io/mosaic-health-cloud-architecture/)
* **Azure Build & Telemetry Monitor:** [https://freefades2black.github.io/mosaic-health-cloud-architecture/dashboards/azure-build-monitor/](https://freefades2black.github.io/mosaic-health-cloud-architecture/dashboards/azure-build-monitor/)
* **AI Foundry Agent Regulation:** [https://freefades2black.github.io/mosaic-health-cloud-architecture/compliance-hitrust/ai-foundry-governance/](https://freefades2black.github.io/mosaic-health-cloud-architecture/compliance-hitrust/ai-foundry-governance/)

---

## License & Architecture Review Board

Copyright &copy; 2026 Mosaic Healthcare Enterprise Architecture & Infrastructure Operations.  
Licensed under the **Apache-2.0 License**.
