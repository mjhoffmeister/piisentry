# PII Sentry

Concentric-ring PII/PHI compliance review solution using a local Copilot SDK agent plus Fabric IQ, Work IQ, and Foundry IQ sources.

## Problem → Solution
- **Problem:** Compliance blind spots exist between codified standards, internal business artifacts, and live regulations.
- **Solution:** A concentric-ring scan model that reconciles all three sources into a single compliance report.

## Current State (Phase 2)
- Infrastructure modules and CI workflow are in place for Foundry, Search, storage, observability, and identity.
- Demo lakehouse seed data is implemented with codified standards and control mappings.
- Work IQ artifact set is implemented with uncodified business updates.
- Foundry IQ regulatory excerpts are prepared for vector indexing and retrieval grounding.
- Foundry post-provision script for Fabric-backed agent creation is implemented in `infra/scripts/create-foundry-agent.sh`.

## Planned Deliverables
- Full architecture and setup documentation
- Ring integrations (Fabric, Work IQ, Foundry IQ)
- Report generation and demo flow
