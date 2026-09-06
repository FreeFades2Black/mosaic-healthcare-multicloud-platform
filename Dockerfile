# Multi-stage Dockerfile for Mosaic Healthcare Multi-Cloud Infrastructure Platform
FROM hashicorp/terraform:1.6.6 AS terraform-base

FROM python:3.11-slim AS validator

WORKDIR /app

# Copy Terraform binary from base stage
COPY --from=terraform-base /bin/terraform /bin/terraform

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Install Open Policy Agent (OPA)
RUN curl -L -o /bin/opa https://openpolicyagent.org/downloads/v0.61.0/opa_linux_amd64_static && \
    chmod 755 /bin/opa

# Install Python test dependencies
RUN pip install --no-cache-dir pytest checkov

# Copy repository code
COPY terraform/ ./terraform/
COPY policies/ ./policies/
COPY tests/ ./tests/
COPY pytest.ini ./
COPY README.md ./

# Non-root user for security
RUN addgroup --gid 10006 mosaic && \
    adduser --uid 10006 --gid 10006 --disabled-password --gecos "" mosaic && \
    chown -R mosaic:mosaic /app

USER 10006:10006

# Default command runs compliance tests
CMD ["python", "-m", "pytest", "tests/", "-v"]
