#!/usr/bin/env bash
set -euo pipefail

# Create the Foundry IQ knowledge base in Azure AI Search for agentic retrieval.
#
# This script:
#   1. Creates a data source connection pointing at the regulatory blob container
#   2. Creates an index with vector + text fields
#   3. Creates a skillset for chunking + embedding
#   4. Creates an indexer to populate the index from blob
#   5. Creates a knowledge base for agentic retrieval (blob + optional Bing)
#
# Prerequisites:
#   - az CLI authenticated (az login)
#   - Regulatory docs uploaded to blob (run upload-regulatory-docs.sh first)
#   - Terraform applied (AI Search + storage account + Foundry project exist)
#   - Caller has Search Service Contributor + Storage Blob Data Reader roles
#
# Usage:
#   ./infra/scripts/create-foundry-iq-knowledge-base.sh
#
# Environment overrides (all optional — defaults read from terraform output):
#   SEARCH_ENDPOINT, STORAGE_ACCOUNT, FOUNDRY_PROJECT_ENDPOINT,
#   KNOWLEDGE_BASE_NAME, BING_CONNECTION_NAME

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# ---------------------------------------------------------------------------
# Resolve values from env or terraform outputs
# ---------------------------------------------------------------------------
resolve() {
	local var_name="$1"
	local tf_output="$2"
	local current="${!var_name:-}"
	if [[ -z "$current" ]]; then
		current="$(terraform -chdir="$REPO_ROOT/infra" output -raw "$tf_output" 2>/dev/null || true)"
	fi
	if [[ -z "$current" ]]; then
		echo "ERROR: Could not resolve $var_name (tried env and terraform output '$tf_output')."
		exit 1
	fi
	printf '%s' "$current"
}

SEARCH_ENDPOINT="$(resolve SEARCH_ENDPOINT search_endpoint)"
STORAGE_ACCOUNT="$(resolve STORAGE_ACCOUNT storage_account_name)"
FOUNDRY_PROJECT_ENDPOINT="$(resolve FOUNDRY_PROJECT_ENDPOINT foundry_project_endpoint)"

KNOWLEDGE_BASE_NAME="${KNOWLEDGE_BASE_NAME:-piisentry-regulatory-kb}"
CONTAINER_NAME="regulatory"
INDEX_NAME="regulatory-index"
DATASOURCE_NAME="regulatory-blob-ds"
INDEXER_NAME="regulatory-indexer"
SKILLSET_NAME="regulatory-skillset"
SEARCH_API="2024-11-01-preview"
KB_API="2025-05-01-preview"

# ---------------------------------------------------------------------------
# Auth
# ---------------------------------------------------------------------------
search_token="$(az account get-access-token --resource https://search.azure.com --query accessToken -o tsv)"
storage_resource_id="/subscriptions/$(az account show --query id -o tsv)/resourceGroups/piisentry-rg/providers/Microsoft.Storage/storageAccounts/$STORAGE_ACCOUNT"

search_put() {
	local path="$1"
	local body="$2"
	curl -fsSL -X PUT "${SEARCH_ENDPOINT}${path}?api-version=${SEARCH_API}" \
		-H "Authorization: Bearer ${search_token}" \
		-H "Content-Type: application/json" \
		-d "$body"
}

search_post() {
	local path="$1"
	local body="$2"
	curl -fsSL -X POST "${SEARCH_ENDPOINT}${path}?api-version=${SEARCH_API}" \
		-H "Authorization: Bearer ${search_token}" \
		-H "Content-Type: application/json" \
		-d "$body"
}

echo "=== Foundry IQ Knowledge Base Setup ==="
echo "Search endpoint:  $SEARCH_ENDPOINT"
echo "Storage account:  $STORAGE_ACCOUNT"
echo "Knowledge base:   $KNOWLEDGE_BASE_NAME"
echo ""

# ---------------------------------------------------------------------------
# 1. Data source connection (blob, managed identity auth)
# ---------------------------------------------------------------------------
echo "1/5  Creating data source '$DATASOURCE_NAME' ..."
ds_body="$(jq -n \
	--arg name "$DATASOURCE_NAME" \
	--arg acct "$STORAGE_ACCOUNT" \
	--arg container "$CONTAINER_NAME" \
	--arg resId "$storage_resource_id" \
	'{
		name: $name,
		type: "azureblob",
		credentials: {
			connectionString: ("ResourceId=\($resId);")
		},
		container: {
			name: $container
		}
	}'
)"
search_put "/datasources/$DATASOURCE_NAME" "$ds_body" >/dev/null
echo "     Done."

# ---------------------------------------------------------------------------
# 2. Index with vector profile (integrated vectorization)
# ---------------------------------------------------------------------------
echo "2/5  Creating index '$INDEX_NAME' ..."
index_body="$(cat <<'INDEXJSON'
{
  "name": "regulatory-index",
  "fields": [
    { "name": "chunk_id",    "type": "Edm.String",  "key": true,  "filterable": true, "sortable": true, "analyzer": "keyword" },
    { "name": "parent_id",   "type": "Edm.String",  "filterable": true },
    { "name": "title",       "type": "Edm.String",  "searchable": true },
    { "name": "chunk",       "type": "Edm.String",  "searchable": true },
    { "name": "text_vector", "type": "Collection(Edm.Single)", "searchable": true,
      "dimensions": 1536,
      "vectorSearchProfile": "default-profile" }
  ],
  "vectorSearch": {
    "algorithms": [
      { "name": "default-hnsw", "kind": "hnsw" }
    ],
    "profiles": [
      {
        "name": "default-profile",
        "algorithm": "default-hnsw"
      }
    ]
  }
}
INDEXJSON
)"
search_put "/indexes/$INDEX_NAME" "$index_body" >/dev/null
echo "     Done."

# ---------------------------------------------------------------------------
# 3. Skillset — text split + embedding via Foundry project
# ---------------------------------------------------------------------------
echo "3/5  Creating skillset '$SKILLSET_NAME' ..."
skillset_body="$(jq -n \
	--arg name "$SKILLSET_NAME" \
	'{
		name: $name,
		description: "Chunk regulatory text and generate embeddings via Foundry project.",
		skills: [
			{
				"@odata.type": "#Microsoft.Skills.Text.SplitSkill",
				name: "split",
				description: "Split into chunks",
				textSplitMode: "pages",
				maximumPageLength: 2000,
				pageOverlapLength: 200,
				context: "/document",
				inputs: [{ name: "text", source: "/document/content" }],
				outputs: [{ name: "textItems", targetName: "pages" }]
			},
			{
				"@odata.type": "#Microsoft.Skills.Text.AzureOpenAIEmbeddingSkill",
				name: "embed",
				description: "Embed chunks",
				context: "/document/pages/*",
				modelName: "text-embedding-ada-002",
				deploymentId: "text-embedding-ada-002",
				resourceUri: "https://piisentry-foundry-dev.openai.azure.com",
				inputs: [{ name: "text", source: "/document/pages/*" }],
				outputs: [{ name: "embedding", targetName: "text_vector" }]
			}
		],
		indexProjections: {
			selectors: [
				{
					targetIndexName: "regulatory-index",
					parentKeyFieldName: "parent_id",
					sourceContext: "/document/pages/*",
					mappings: [
						{ name: "chunk",       source: "/document/pages/*" },
						{ name: "text_vector", source: "/document/pages/*/text_vector" },
						{ name: "title",       source: "/document/metadata_storage_name" }
					]
				}
			],
			parameters: { projectionMode: "skipIndexingParentDocuments" }
		}
	}'
)"
search_put "/skillsets/$SKILLSET_NAME" "$skillset_body" >/dev/null
echo "     Done."

# ---------------------------------------------------------------------------
# 4. Indexer — connects data source → skillset → index
# ---------------------------------------------------------------------------
echo "4/5  Creating indexer '$INDEXER_NAME' ..."
indexer_body="$(jq -n \
	--arg name "$INDEXER_NAME" \
	--arg ds "$DATASOURCE_NAME" \
	--arg idx "$INDEX_NAME" \
	--arg ss "$SKILLSET_NAME" \
	'{
		name: $name,
		dataSourceName: $ds,
		targetIndexName: $idx,
		skillsetName: $ss,
		parameters: {
			configuration: {
				parsingMode: "default",
				dataToExtract: "contentAndMetadata"
			}
		}
	}'
)"
search_put "/indexers/$INDEXER_NAME" "$indexer_body" >/dev/null
echo "     Done."

# ---------------------------------------------------------------------------
# 5. Trigger indexer run
# ---------------------------------------------------------------------------
echo "5/5  Running indexer '$INDEXER_NAME' ..."
search_post "/indexers/$INDEXER_NAME/run" "{}" >/dev/null 2>&1 || true
echo "     Indexer triggered. Check status with:"
echo "     curl '${SEARCH_ENDPOINT}/indexers/${INDEXER_NAME}/status?api-version=${SEARCH_API}' -H 'Authorization: Bearer <token>'"

echo ""
echo "=== Setup complete ==="
echo ""
echo "NOTE: Knowledge base creation for agentic retrieval (knowledgebases API)"
echo "is currently portal-only in preview. After the indexer finishes, create"
echo "the knowledge base named '$KNOWLEDGE_BASE_NAME' in the Foundry portal:"
echo "  1. Open the Foundry project: $FOUNDRY_PROJECT_ENDPOINT"
echo "  2. Go to Knowledge Bases → Create"
echo "  3. Add a 'blob' knowledge source pointing at index '$INDEX_NAME'"
echo "  4. (Optional) Add a 'Bing' web knowledge source for real-time lookups"
echo "  5. Name it '$KNOWLEDGE_BASE_NAME'"
