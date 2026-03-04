# Demo Data (Phase 2)

This folder contains the complete Phase 2 demo corpus used by the three-ring compliance model.

## Layout

- `lakehouse/`: Fabric IQ codified standards tables (CSV seed files).
- `docs/`: Work IQ business artifacts representing uncodified policy updates.
- `regulatory/`: Foundry IQ regulatory excerpts for authoritative external grounding.

## Ring Mapping

- Ring 1 (Fabric Data Agent): `lakehouse/*.csv`
- Ring 2 (Work IQ): `docs/*.md` (standing in for SharePoint/Word/email content)
- Ring 3 (Foundry IQ): `regulatory/*.txt`

## Intentional Knowledge Gaps

The dataset is intentionally non-uniform to demonstrate reconciliation behavior:

- Lakehouse includes older controls (for example, SSN encryption at rest with `AES-128`).
- Work IQ artifacts introduce newer operating guidance (for example, `AES-256-GCM` and explicit biometric consent).
- Regulatory excerpts add higher-authority obligations not codified elsewhere (for example, GDPR Article 35 DPIA requirements).

## Lakehouse Seed Tables

- `pii_data_categories.csv`
- `phi_data_categories.csv`
- `data_handling_requirements.csv`
- `compliance_controls.csv`
- `application_systems.csv`
- `data_flows.csv`

`application_systems.csv` and `data_flows.csv` are denormalized and must stay synchronized on `(FlowId, CategoryId, CategoryType)`.

## Usage Notes

- Upload `lakehouse/*.csv` to the Fabric lakehouse and load into tables with matching names.
- Ensure Data Agent instructions reference wildcard requirements where `CategoryId = *`.
- Index `regulatory/*.txt` into the Foundry IQ vector source and configure the Bing source for web-grounded retrieval.
