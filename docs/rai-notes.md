# Responsible AI Notes

## Data Minimization
The CLI reads source code locally and sends only natural-language queries to IQ sources. Raw code and PII values found during scanning are never transmitted to external services. Ring tool queries ask about organizational standards, business policies, and regulatory requirements — not about the code itself.

## Transparency
Every finding in the report includes the intelligence ring that provided the evidence and a specific citation (e.g., "Fabric Data Agent: data_handling_requirements row — AES-256 encryption required"). Findings without ring evidence are suppressed — no general-knowledge fabrication.

## Permission-Aware Access
Fabric IQ and Foundry IQ authenticate with the user's Azure identity (via InteractiveBrowserCredential with MSAL token cache). Work IQ runs through the Copilot SDK session using the user's M365/GitHub Copilot identity. Each ring respects its own access controls independently — Fabric workspace permissions, M365 Graph ACLs, and AI Search RBAC roles respectively. The CI/CD service principal is used only for infrastructure provisioning.

## Human Oversight
Findings are recommendations, not automated enforcement. The report includes severity levels and remediation guidance, but human review is required before implementing changes. The Markdown report format is designed to be handed to a coding assistant for implementation planning.

## No Data Retention
The CLI does not persist any PII/PHI discovered during scans. Reports are generated locally. Application Insights telemetry tracks only scan lifecycle events (duration, finding counts, ring availability) — never code content or PII values.

## Bias and Fairness
Regulatory analysis is grounded in indexed source documents (HIPAA, GDPR, CCPA excerpts), not model opinion. Citations ensure auditability. The concentric-ring model explicitly separates codified standards from uncodified business knowledge and regulatory requirements, making the provenance of each finding clear.
