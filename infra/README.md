# Infrastructure (Phase 1)

This folder provisions baseline PII Sentry Azure resources using Terraform with `azapi ~> 2.8.0`.

Implemented modules:
- `modules/ai-search`: Azure AI Search service
- `modules/ai-foundry`: Foundry account, project, and optional Fabric connection
- `modules/storage`: Storage account and `regulatory` blob container
- `modules/observability`: Log Analytics + Application Insights
- `modules/fabric`: Fabric capacity + optional workspace + optional lakehouse + optional workspace Git integration
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

## Fabric Automation (Phase 2)

Prefer Terraform first, then scripts only for data-plane gaps.

### Terraform-managed

- Fabric capacity (`azapi`)
- Fabric workspace (`fabric_workspace`)
- Fabric lakehouse (`fabric_lakehouse`)
- Fabric workspace Git integration (`fabric_workspace_git`, optional)

Key vars:

- `create_fabric_capacity`
- `create_fabric_workspace`
- `create_fabric_lakehouse`
- `create_fabric_workspace_git`
- `fabric_workspace_display_name`
- `fabric_lakehouse_display_name`
- `fabric_workspace_git_repository_owner`
- `fabric_workspace_git_repository_name`
- `fabric_workspace_git_branch_name`
- `fabric_workspace_git_directory_name`
- `fabric_workspace_git_connection_id`

Example:

```bash
terraform -chdir=infra apply \
	-var="create_fabric_capacity=true" \
	-var="create_fabric_workspace=true" \
	-var="create_fabric_lakehouse=true" \
	-var="fabric_workspace_display_name=WS_PII_Sentry" \
	-var="fabric_lakehouse_display_name=LH_PII_Sentry"
```

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

### 4. Bootstrap Fabric Ring 1 data-plane resources (script)

Creates repeatable Data Agent setup using APIs:

- Uploads `demo-data/lakehouse/*.csv` to OneLake Files
- Loads all six lakehouse tables via Fabric Lakehouse API
- Creates or updates `DA_PII_Sentry` from `demo-fabric-artifacts/DA_PII_Sentry.DataAgent`

```bash
./infra/scripts/bootstrap-fabric-ring1.sh
```

This script is idempotent and can be re-run safely.
