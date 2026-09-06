# ==================================================================================================
# DOCKERFILE: MOSAIC HEALTHCARE CLINICAL INGESTION MICROSERVICE
# Multi-Cloud Portability: Deploys to AWS ECS/Fargate, Azure Container Apps, or Kubernetes (EKS/AKS)
# Security Standard: CIS Benchmark Non-Root Execution (UID 10007)
# ==================================================================================================

# Stage 1: Build & Dependency Resolution
FROM python:3.11-slim AS builder

WORKDIR /app

# Install system utilities
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install dependencies into wheels cache
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Stage 2: Ultra-Lightweight Production Runtime
FROM python:3.11-slim AS runtime

WORKDIR /app

# Install curl for healthcheck probes
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy installed Python packages from builder
COPY --from=builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin

# Copy microservice application source code
COPY ingestion_service.py ./

# Create non-root user and group
RUN addgroup --gid 10007 mosaic_ingest && \
    adduser --uid 10007 --gid 10007 --disabled-password --gecos "" mosaic_ingest && \
    mkdir -p /tmp/mosaic/bronze && \
    chown -R mosaic_ingest:mosaic_ingest /app /tmp/mosaic

USER 10007:10007

EXPOSE 8080

# Kubernetes & Container Healthcheck probe
HEALTHCHECK --interval=15s --timeout=5s --retries=3 \
    CMD curl -f http://localhost:8080/healthz || exit 1

# Launch microservice via Uvicorn ASGI server
CMD ["uvicorn", "ingestion_service:app", "--host", "0.0.0.0", "--port", "8080"]
