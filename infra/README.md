# Infrastructure (Phase 1)

This folder provisions baseline PII Sentry Azure resources using Terraform with `azapi ~> 2.8.0`.

Implemented modules:
- `modules/ai-search`: Azure AI Search service
- `modules/ai-foundry`: Foundry account, project, and optional Fabric connection
- `modules/storage`: Storage account and `regulatory` blob container
- `modules/observability`: Log Analytics + Application Insights
- `modules/fabric`: Fabric capacity
- `modules/identity`: User-assigned identity + bootstrap RBAC assignments

## Prerequisites

- Azure provider registration:
	- `az provider register --namespace Microsoft.CognitiveServices`
- GitHub Actions WIF secrets for CI:
	- `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`
	- `AZURE_ADMIN_OBJECT_ID` (optional but recommended for bootstrap role assignments)
	- `AZURE_FABRIC_CONNECTION_TARGET` (required when `TF_VAR_create_fabric_connection=true`)

## Validate Locally

- `terraform -chdir=infra init -backend=false`
- `terraform -chdir=infra fmt -check -recursive`
- `terraform -chdir=infra validate`

## Post-Provisioning Scripts

Run these after `terraform apply` to configure data-plane resources.

### 1. Upload regulatory docs to blob storage

```bash
# Uses terraform output for storage account name, or set STORAGE_ACCOUNT env var
./infra/scripts/upload-regulatory-docs.sh
```

### 2. Create AI Search index for Foundry IQ

```bash
# Creates data source, index, skillset, and indexer for regulatory text
./infra/scripts/create-foundry-iq-knowledge-base.sh
```

After the indexer completes, create the knowledge base in the Foundry portal (agentic retrieval KB API is portal-only in preview).

### 3. Create Foundry agent with Fabric Data Agent

```bash
# Requires FOUNDRY_PROJECT_ENDPOINT and FABRIC_CONNECTION_ID
./infra/scripts/create-foundry-agent.sh
```
