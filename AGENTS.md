# AGENTS.md

## Purpose
This repository implements **PII Sentry**, a .NET 10 CLI that performs concentric-ring PII/PHI compliance analysis.

## Architecture Baseline
- Single deployable artifact: `PiiSentry.Cli` (`dotnet tool` target in later phases).
- Shared contracts and reporting live in `PiiSentry.Core`.
- `PiiSentry.DemoApp` provides intentionally non-compliant code for demonstrations.

## Two-Layer Agent Model
- Local reasoning agent: Copilot SDK agent running in-process inside `PiiSentry.Cli`.
  - Primary types: `CopilotClient`, `AIAgent`, `SessionConfig`, `OnPermissionRequest`.
  - Responsibilities: file analysis, ring orchestration, reconciliation, and report synthesis.
- Remote Ring 1 execution agent: Foundry agent in Azure Agent Service.
  - Wraps `FabricTool` to query the Fabric Data Agent.
  - CLI references a stable agent ID and creates a disposable thread per scan.

## IQ Source Rings
- Ring 1: Fabric Data Agent through Foundry Agent Service (lakehouse-backed codified standards).
- Ring 2: Work IQ MCP (uncodified business artifacts from M365).
- Ring 3: Foundry IQ / AI Search retrieval (regulatory intelligence).

## Repository Conventions
- Keep changes scoped to the active phase in `plans/plan.md`.
- Prefer small, focused commits and avoid unrelated refactors.
- Do not store secrets in source; use environment variables or CI secrets.
- Keep generated reports local by default.

## Build & Validate
- Restore/build: `dotnet restore PiiSentry.slnx` then `dotnet build PiiSentry.slnx --configuration Release`
- Verify format: `dotnet format --verify-no-changes --verbosity diagnostic`
- Run tests (when present): `dotnet test PiiSentry.slnx`
- Validate Terraform stubs: `terraform -chdir=infra init -backend=false`, `terraform -chdir=infra validate`, and `terraform -chdir=infra fmt -check -recursive`

## Deployment
- Infrastructure: `cd infra && terraform init && terraform apply`
- Fabric setup: Create lakehouse, load CSVs, configure Data Agent
- Foundry agent: `infra/scripts/create-foundry-agent.sh`
- Fabric auth (CMK): `infra/scripts/Setup-FabricAuth.ps1`

## Phase 0 Scope
- Scaffold folder structure, baseline projects, CI stub, docs stubs, and MCP configuration.
- Keep implementation lightweight and compile-ready.
