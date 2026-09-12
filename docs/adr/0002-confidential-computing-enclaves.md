# ADR-0002: PHI De-Identification in AWS Nitro Enclaves and Azure Confidential VMs

**Status:** Accepted  
**Date:** 2026-07-11  
**Lead Architect:** William Free Hall (Free) <whall4.wh@gmail.com>

## 1. Context & Operational Challenge
De-identifying clinical trial data requires processing raw medical records containing Social Security Numbers and patient identifiers. Cloud administrators or compromised hosts must not have memory-dump access to unencrypted PHI during computation.

## 2. Options Considered
* **Option A: Standard Containerized Microservices in Private Subnets**
  - *Evaluation:* Relies on OS-level isolation; any root-privileged attacker on the host node can dump process memory and inspect ePHI.
* **Option B: Hardware-Attested Confidential Computing Enclaves (AWS Nitro / Azure AMD SEV-SNP)**
  - *Evaluation:* Cryptographically isolates CPU memory from the hypervisor and host OS; cryptographic attestation guarantees that only signed, unmodified code runs inside the enclave.

## 3. Decision & Trade-Off Accepted
We adopted **Option B (Hardware Enclaves)**.  
**Trade-Off Accepted:** Increases compute node instance pricing by approximately 15%; requires local vsock communication libraries rather than standard TCP sockets.
