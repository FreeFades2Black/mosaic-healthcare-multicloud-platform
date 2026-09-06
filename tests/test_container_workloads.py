"""
==================================================================================================
MOSAIC HEALTHCARE MULTI-CLOUD PLATFORM
Container Workloads & Microservice Test Suite (tests/test_container_workloads.py)
Validates cross-cloud microservices, Kubernetes manifests, and Compose orchestrators.
==================================================================================================
"""

import pytest
import sys
from pathlib import Path
from fastapi.testclient import TestClient

PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT / "containers" / "clinical_ingestion"))
sys.path.insert(0, str(PROJECT_ROOT / "containers" / "clinical_analytics"))

from ingestion_service import app as ingestion_app
from analytics_service import app as analytics_app


def test_clinical_ingestion_microservice_health_and_ingestion():
    """Verify clinical ingestion FastAPI microservice processes FHIR encounters."""
    client = TestClient(ingestion_app)

    # 1. Test Health Probe
    health_resp = client.get("/healthz")
    assert health_resp.status_code == 200
    assert health_resp.json()["status"] == "HEALTHY"

    # 2. Test Clinical Encounter Ingestion
    payload = {
        "encounter_id": "ENC-TEST-9001",
        "patient_id_pseudonym": "PAT-HASH-8832049",
        "facility_ccn": "420078",
        "encounter_type": "EMERGENCY",
        "observations": [
            {
                "code": "883-9",
                "display": "ABO and Rh group",
                "value": 1.0,
                "unit": "group"
            },
            {
                "code": "8310-5",
                "display": "Body temperature",
                "value": 37.2,
                "unit": "Cel"
            }
        ]
    }
    ingest_resp = client.post("/api/v1/ingest/encounter", json=payload)
    assert ingest_resp.status_code == 201
    assert ingest_resp.json()["status"] == "INGESTED_TO_BRONZE"
    assert ingest_resp.json()["encounter_id"] == "ENC-TEST-9001"


def test_clinical_analytics_microservice_health_and_forecasts():
    """Verify clinical analytics FastAPI microservice generates bed surge projections."""
    client = TestClient(analytics_app)

    # 1. Test Health Probe
    health_resp = client.get("/healthz")
    assert health_resp.status_code == 200
    assert health_resp.json()["status"] == "HEALTHY"

    # 2. Test Bed Surge Summary
    summary_resp = client.get("/api/v1/analytics/bed-surge/summary")
    assert summary_resp.status_code == 200
    data = summary_resp.json()
    assert "facilities" in data
    assert len(data["facilities"]) >= 2
    assert data["facilities"][0]["facility_ccn"] == "420078"


def test_docker_compose_multicloud_manifest_integrity():
    """Verify docker-compose.multicloud.yml defines all 3 core services and volumes."""
    compose_path = PROJECT_ROOT / "docker-compose.multicloud.yml"
    assert compose_path.exists()

    content = compose_path.read_text(encoding="utf-8")
    assert "clinical-ingestion-service:" in content
    assert "clinical-analytics-service:" in content
    assert "terraform-compliance-validator:" in content
    assert "mosaic_shared_medallion:" in content


def test_kubernetes_manifests_non_root_security():
    """Verify Kubernetes manifests enforce non-root UID execution."""
    ingest_k8s = PROJECT_ROOT / "k8s" / "base" / "deployment-ingestion.yaml"
    analytics_k8s = PROJECT_ROOT / "k8s" / "base" / "deployment-analytics.yaml"

    assert ingest_k8s.exists()
    assert analytics_k8s.exists()

    ingest_text = ingest_k8s.read_text(encoding="utf-8")
    assert "runAsNonRoot: true" in ingest_text
    assert "runAsUser: 10007" in ingest_text

    analytics_text = analytics_k8s.read_text(encoding="utf-8")
    assert "runAsNonRoot: true" in analytics_text
    assert "runAsUser: 10008" in analytics_text
