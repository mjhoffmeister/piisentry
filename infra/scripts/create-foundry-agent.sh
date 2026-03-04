#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${FOUNDRY_PROJECT_ENDPOINT:-}" ]]; then
	echo "FOUNDRY_PROJECT_ENDPOINT is not set; skipping Foundry agent provisioning."
	exit 0
fi

if [[ -z "${FABRIC_CONNECTION_ID:-}" ]]; then
	echo "FABRIC_CONNECTION_ID is not set; skipping Foundry agent provisioning."
	exit 0
fi

agent_name="${FOUNDRY_AGENT_NAME:-piisentry-fabric-agent}"
agent_model="${FOUNDRY_AGENT_MODEL:-gpt-4o}"
api_version="2025-05-15-preview"
assistants_url="${FOUNDRY_PROJECT_ENDPOINT%/}/assistants?api-version=${api_version}"

token="$(az account get-access-token --resource https://cognitiveservices.azure.com --query accessToken -o tsv)"

existing_agent_id="$(
	curl -fsSL -X GET "$assistants_url" \
		-H "Authorization: Bearer ${token}" \
		-H "Content-Type: application/json" \
	| jq -r --arg n "$agent_name" '.data[]? | select(.name == $n) | .id' \
	| head -n 1
)"

if [[ -n "$existing_agent_id" ]]; then
	echo "Found existing Foundry agent '$agent_name': $existing_agent_id"
	if [[ -n "${GITHUB_ENV:-}" ]]; then
		echo "FOUNDRY_FABRIC_AGENT_ID=$existing_agent_id" >> "$GITHUB_ENV"
	fi
	if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
		echo "foundry_fabric_agent_id=$existing_agent_id" >> "$GITHUB_OUTPUT"
	fi
	exit 0
fi

create_body="$(jq -n \
	--arg name "$agent_name" \
	--arg model "$agent_model" \
	--arg cid "$FABRIC_CONNECTION_ID" \
	'{
		name: $name,
		model: $model,
		instructions: "You are a compliance knowledge base. Answer questions about PII/PHI handling standards.",
		tools: [
			{
				type: "fabric",
				fabric: {
					connection_id: $cid
				}
			}
		]
	}'
)"

created_agent_id="$(
	curl -fsSL -X POST "$assistants_url" \
		-H "Authorization: Bearer ${token}" \
		-H "Content-Type: application/json" \
		-d "$create_body" \
	| jq -r '.id'
)"

if [[ -z "$created_agent_id" || "$created_agent_id" == "null" ]]; then
	echo "Failed to create Foundry agent '$agent_name'."
	exit 1
fi

echo "Created Foundry agent '$agent_name': $created_agent_id"

if [[ -n "${GITHUB_ENV:-}" ]]; then
	echo "FOUNDRY_FABRIC_AGENT_ID=$created_agent_id" >> "$GITHUB_ENV"
fi

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
	echo "foundry_fabric_agent_id=$created_agent_id" >> "$GITHUB_OUTPUT"
fi
