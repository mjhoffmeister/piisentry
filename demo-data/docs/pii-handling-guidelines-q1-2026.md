# Updated PII Handling Guidelines Q1 2026

Effective date: 2026-01-01
Owner: Security and Compliance Council

## Summary
This update documents policy decisions that were approved in Q4 2025 and become mandatory in Q1 2026. These updates are more specific than some existing codified standards and must be treated as current operating guidance until codified tables are updated.

## Mandatory Changes

1. Social Security Numbers (SSN) at rest
- Effective Q1 2026, all SSNs must be encrypted at rest using `AES-256-GCM`.
- The previous `AES-128-CBC` baseline is no longer acceptable for SSN fields.
- Migration plans for existing SSN stores must include re-encryption and key rotation validation.

2. Biometric data consent workflow
- Biometric data collected from employees or patients must have an explicit consent workflow before any processing.
- The workflow must include:
  - Informed consent capture before collection
  - Clear purpose statement
  - Opt-out capability
  - Consent audit trail with timestamp and policy version
- If consent is missing or revoked, biometric processing must be blocked.

3. Logging and telemetry controls
- Biometric identifiers and SSN values must not appear in plaintext logs.
- Security events for consent denials and revocations must be logged in a dedicated audit stream.

## Implementation Guidance

- Update service and database encryption policies to enforce `AES-256-GCM` for SSN-specific storage paths.
- Add consent checks at API entry points and service-level processing boundaries.
- Validate that downstream analytics and export jobs honor consent state.

## Open Action Items

- Codify these requirements in lakehouse requirements and controls tables.
- Add automated tests that fail builds when SSN storage paths do not meet `AES-256-GCM` policy.
- Add quarterly access and consent workflow audits.
