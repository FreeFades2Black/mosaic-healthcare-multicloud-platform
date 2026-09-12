# Incident Post-Mortem: WORM Immutability Policy Blocking Daily Test Environment Tear-Down

**Incident Date:** 2026-07-14  
**Impact Duration:** 45 minutes  
**Severity:** SEV-3  
**Root Cause:** A developer mistakenly executed an integration test suite targeting the production-compliant WORM storage container with an enforced 6-year retention policy. Automated end-of-day Terraform destroy jobs failed with `StorageAccountIsLockedUnderRetention`.

## Timeline
* **18:00 UTC:** Scheduled CI teardown job initiated `terraform destroy` on ephemeral staging resources.
* **18:05 UTC:** Terraform halted on Azure Blob container: `Cannot delete container with active immutability policy`.
* **18:20 UTC:** Incident team identified that the environment variable `WORM_RETENTION_DAYS` defaulted to `2190` rather than `1` for test accounts.
* **18:45 UTC:** Implemented Terraform conditional logic enforcing that production compliance locks can only be provisioned in designated production subscriptions.

## Corrective Actions
1. Added policy-as-code check in `test_terraform_compliance.py` asserting that non-production environments must use `legal_hold = false` and `retention_days = 0`.
2. Created separate subscription boundary for production HIPAA storage accounts.
