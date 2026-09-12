## Multi-Cloud Platform Operational Overview
*Describe the cross-cloud infrastructure, container workload, or compliance policy changes.*

- [ ] Multi-Cloud Terraform Infrastructure (AWS + Azure)
- [ ] Container Workload Specification
- [ ] Cross-Cloud Network / IPsec Tunneling
- [ ] HIPAA Compliance & WORM Storage Policy

## Safety & Compliance Verification
- **Multi-Cloud Parity:** Verified configurations apply consistently across AWS and Azure.
- **WORM Retention Safety:** Confirmed test environments do not apply immutable 6-year production locks.

## Verification Checklist
- [ ] Test suite passed (12/12 tests): `python -m pytest tests/ -v`
- [ ] Container workload verification clean: `python -m pytest tests/test_container_workloads.py`
- [ ] Terraform compliance rules validated: `python -m pytest tests/test_terraform_compliance.py`
