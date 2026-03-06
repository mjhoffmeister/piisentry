# PII Sentry

Concentric-ring PII/PHI compliance analysis CLI powered by the GitHub Copilot SDK.

## Problem

Organizations maintain PII/PHI handling standards across three disconnected silos: codified policies in data platforms, uncodified business knowledge in M365 artifacts, and evolving regulatory requirements. Compliance reviews that check only one source leave blind spots that create real risk.

## Solution

PII Sentry is a .NET 10 CLI that uses the GitHub Copilot SDK to orchestrate a concentric-ring compliance scan. It reads source code, queries three intelligence rings in parallel, and produces a unified report with grounded findings, cross-ring reconciliation, and a file-grouped remediation plan.

- **Fabric IQ** (Ring 1) — Codified organizational standards from a Fabric Lakehouse via Foundry Agent Service
- **Work IQ** (Ring 2) — Uncodified business knowledge from M365 via native MCP server
- **Foundry IQ** (Ring 3) — Regulatory intelligence from HIPAA, GDPR, and CCPA documents via Azure AI Search agentic retrieval

## Prerequisites

- .NET 10 SDK
- Azure subscription with:
  - AI Foundry resource + project
  - Azure AI Search (S0+) with agentic retrieval knowledge base
  - Fabric capacity (F4+) with workspace, lakehouse, and Data Agent
  - Storage account for regulatory document blob storage
- GitHub Copilot license (for the Copilot SDK)
- Node.js 18+ (for Work IQ MCP via npx)

## Setup

1. **Infrastructure:** `cd infra && terraform init && terraform apply`
2. **Fabric:** Create lakehouse, load CSV data from `demo-data/lakehouse/`, configure Data Agent
3. **Foundry Agent:** Run `infra/scripts/create-foundry-agent.sh` to create the Foundry agent with FabricTool
4. **Regulatory Docs:** Run `infra/scripts/upload-regulatory-docs.sh` to upload to blob storage for AI Search indexing
5. **Fabric Auth (CMK):** If the subscription enforces Customer-Managed Keys on Fabric, run:
   ```powershell
   .\infra\scripts\Setup-FabricAuth.ps1 `
       -SubscriptionId "<sub-id>" -ResourceGroup "<kv-rg>" `
       -KeyVaultName "<kv-name>" -AdminUpn "<admin@tenant.onmicrosoft.com>"
   ```
   This grants the Fabric service principal access to the CMK in Key Vault. See script for details.
6. **Configuration:** Copy `src/PiiSentry.Cli/appsettings.json` and fill in endpoint values

## Usage

```bash
# Scan with all rings, output as Markdown
pii-sentry scan ./src/PiiSentry.DemoApp --ring all --output report.md

# Scan with specific ring
pii-sentry scan <path> --ring fabric --output report.json

# Output formats: .md (Markdown, recommended), .html (HTML), .json (JSON)
```

### Install as a global tool

```bash
dotnet tool install --global PiiSentry.Cli
```

## Architecture

See [architecture.md](architecture.md) for the full diagram and component descriptions.

## Responsible AI

See [rai-notes.md](rai-notes.md) for data minimization, transparency, and human oversight practices.

## Repository Structure

```
src/PiiSentry.Cli/       — .NET 10 CLI (Copilot SDK agent, ring tools, report generation)
src/PiiSentry.Core/      — Shared models, contracts, report generation
src/PiiSentry.DemoApp/   — Intentionally non-compliant demo app for testing
infra/                   — Terraform (AzApi) modules for Azure infrastructure
demo-data/               — Lakehouse seed CSVs, regulatory text excerpts
docs/                    — Documentation, architecture diagram, RAI notes
presentations/           — PiiSentry.pptx submission deck
AGENTS.md                — Coding agent instructions
mcp.json                 — Work IQ MCP server configuration
```
