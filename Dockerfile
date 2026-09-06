# ==================================================================================================
# MULTI-STAGE DOCKERFILE FOR MOSAIC HEALTHCARE MULTI-CLOUD INFRASTRUCTURE PLATFORM
# Purpose: Isolated, reproducible local testing of Terraform syntax, OPA policies, and PyTest
# ==================================================================================================

# --------------------------------------------------------------------------------------------------
# STAGE 1: TERRAFORM BINARY EXTRACTOR
# Pulls official HashiCorp Terraform binary
# --------------------------------------------------------------------------------------------------
FROM hashicorp/terraform:1.6.6 AS terraform-base

# --------------------------------------------------------------------------------------------------
# STAGE 2: PRODUCTION VALIDATOR & POLICY RUNNER
# Hardened Debian slim container equipped with OPA, Checkov, and PyTest
# --------------------------------------------------------------------------------------------------
FROM python:3.11-slim AS validator

WORKDIR /app

# Copy Terraform CLI binary directly from base stage
COPY --from=terraform-base /bin/terraform /bin/terraform

# Install minimal system dependencies (curl for OPA binary, git for provider hooks)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Install Open Policy Agent (OPA) CLI for Policy-as-Code evaluation
RUN curl -L -o /bin/opa https://openpolicyagent.org/downloads/v0.61.0/opa_linux_amd64_static && \
    chmod 755 /bin/opa

# Install Python testing frameworks and static analysis scanners
RUN pip install --no-cache-dir pytest checkov

# Copy repository codebases into container workspace
COPY terraform/ ./terraform/
COPY policies/ ./policies/
COPY tests/ ./tests/
COPY pytest.ini ./
COPY README.md ./

# Create non-root user and group adhering to CIS Benchmark & DoD container hardening guidelines
RUN addgroup --gid 10006 mosaic && \
    adduser --uid 10006 --gid 10006 --disabled-password --gecos "" mosaic && \
    chown -R mosaic:mosaic /app

# Switch to non-root execution context
USER 10006:10006

# Default command executes full PyTest compliance test suite
CMD ["python", "-m", "pytest", "tests/", "-v"]
