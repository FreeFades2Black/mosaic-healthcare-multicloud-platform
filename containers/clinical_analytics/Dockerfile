# ==================================================================================================
# DOCKERFILE: MOSAIC HEALTHCARE CLINICAL ANALYTICS & BED SURGE MICROSERVICE
# Multi-Cloud Portability: Deploys to AWS ECS/App Runner, Azure Container Apps, or Kubernetes
# Security Standard: CIS Benchmark Non-Root Execution (UID 10008)
# ==================================================================================================

# Stage 1: Build & Dependency Resolution
FROM python:3.11-slim AS builder

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Stage 2: Ultra-Lightweight Production Runtime
FROM python:3.11-slim AS runtime

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin

COPY analytics_service.py ./

RUN addgroup --gid 10008 mosaic_analytics && \
    adduser --uid 10008 --gid 10008 --disabled-password --gecos "" mosaic_analytics && \
    mkdir -p /tmp/mosaic/gold && \
    chown -R mosaic_analytics:mosaic_analytics /app /tmp/mosaic

USER 10008:10008

EXPOSE 8090

HEALTHCHECK --interval=15s --timeout=5s --retries=3 \
    CMD curl -f http://localhost:8090/healthz || exit 1

CMD ["uvicorn", "analytics_service:app", "--host", "0.0.0.0", "--port", "8090"]
