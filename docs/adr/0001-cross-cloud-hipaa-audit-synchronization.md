# ADR-0001: Bi-Directional Immutable Audit Synchronization Between AWS S3 Object Lock and Azure WORM

**Status:** Accepted  
**Date:** 2026-06-19  
**Lead Architect:** William Free Hall (Free) <whall4.wh@gmail.com>

## 1. Context & Operational Challenge
Our healthcare workloads operate concurrently across AWS (EKS compute) and Azure (Health Data Services). To ensure compliance with HIPAA audit trails, ePHI event logs generated in either cloud must be mirrored cross-cloud with immutable write-once-read-many (WORM) locks without introducing circular replication loops.

## 2. Options Considered
* **Option A: Centralized Single-Cloud Audit Bucket with Cross-Cloud IAM Access**
  - *Evaluation:* Simpler architecture, but introduces a single point of failure if the target cloud provider suffers a regional control-plane outage.
* **Option B: Dual-Cloud Autonomous Storage with Event-Driven Bi-Directional Mirroring**
  - *Evaluation:* AWS S3 Object Lock (Compliance Mode) and Azure Blob Storage Immutability Policies operate independently; a serverless replicator tags mirrored objects with origin metadata to terminate replication recursion.

## 3. Decision & Trade-Off Accepted
We adopted **Option B (Dual-Cloud Autonomous WORM Storage)**.  
**Trade-Off Accepted:** Storage egress costs (~$0.02/GB) incurred during cross-cloud replication; replication lag must be monitored to ensure synchronization remains under 60 seconds.
