# Legal Team Meeting Summary: Genetic Privacy Requirements (2026)

Meeting date: 2026-02-10
Participants: Legal, Privacy Office, Security Architecture

## Topic
Review of new state-level genetic privacy obligations and impact on product workflows.

## Key Decision
Illinois Genetic Information Privacy Act (GIPA) obligations are in scope for workloads that collect, analyze, or retain genetic data.

## Legal Notes

- Effective 2026, explicit written consent is required before collecting, analyzing, or retaining genetic data covered by GIPA.
- Consent must be purpose-specific and retained as evidence.
- This requirement applies even when the workflow is non-clinical.
- Existing generalized privacy consent is not sufficient for genetic processing use cases.

## Impacted Scenarios

- Genetic marker screening pipelines
- Partner data sharing workflows involving genetic indicators
- Internal analytics features that derive or infer genetic risk markers

## Required Controls

1. Add consent checks before ingestion and before downstream analysis.
2. Block processing if no active written consent is on file.
3. Record consent provenance for audit and legal discovery.
4. Re-validate consent for materially changed processing purposes.

## Follow-up

- Engineering to implement a consent gate for all genetic processing entry points.
- Compliance to publish implementation checklist and control testing procedure.
- Data governance to update retention and access policy mapping for genetic records.
