# AGENTS.md

## Purpose
This repository implements **PII Sentry**, a .NET 10 CLI that performs concentric-ring PII/PHI compliance analysis.

## Architecture Baseline
- Single deployable artifact: `PiiSentry.Cli` (`dotnet tool` target in later phases).
- Shared contracts and reporting live in `PiiSentry.Core`.
- `PiiSentry.DemoApp` provides intentionally non-compliant code for demonstrations.
- IQ sources are integrated in later phases:
  - Ring 1: Fabric Data Agent through Foundry Agent Service
  - Ring 2: Work IQ MCP
  - Ring 3: Foundry IQ (AI Search retrieval)

## Repository Conventions
- Keep changes scoped to the active phase in `plans/plan.md`.
- Prefer small, focused commits and avoid unrelated refactors.
- Do not store secrets in source; use environment variables or CI secrets.
- Keep generated reports local by default.

## Build & Validate
- Build solution: `dotnet build PiiSentry.slnx`
- Run tests (when present): `dotnet test PiiSentry.slnx`
- Validate Terraform stubs: `terraform -chdir=infra init -backend=false` and `terraform -chdir=infra validate`

## Phase 0 Scope
- Scaffold folder structure, baseline projects, CI stub, docs stubs, and MCP configuration.
- Keep implementation lightweight and compile-ready.
