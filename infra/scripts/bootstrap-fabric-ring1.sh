#!/usr/bin/env bash
set -euo pipefail

# Bootstrap Phase 2 Ring 1 (Fabric IQ) assets in an idempotent way.
#
# What this script does:
# 1) Uploads lakehouse CSV seed files to OneLake Files/
# 2) Loads/overwrites the six lakehouse tables from those CSVs
# 3) Creates or updates the Data Agent definition from demo-fabric-artifacts
#
# Prerequisites:
# - terraform apply already created Fabric workspace + lakehouse outputs
# - az CLI login is active (user or SP with required Fabric/OneLake rights)
# - jq, curl available in PATH
#
# Usage:
#   ./infra/scripts/bootstrap-fabric-ring1.sh
#
# Optional overrides:
#   TF_DIR, WORKSPACE_ID, LAKEHOUSE_ID, DATA_AGENT_NAME, DATA_AGENT_DESCRIPTION

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TF_DIR="${TF_DIR:-$REPO_ROOT/infra}"

DATA_AGENT_NAME="${DATA_AGENT_NAME:-DA_PII_Sentry}"
DATA_AGENT_DESCRIPTION="${DATA_AGENT_DESCRIPTION:-PII Sentry Fabric data agent}"
AUTO_TFVARS_PATH="${AUTO_TFVARS_PATH:-$TF_DIR/auto.fabric-connection.auto.tfvars.json}"
SKIP_TABLE_LOADS="${SKIP_TABLE_LOADS:-false}"
ALLOW_SQL_ENDPOINT_FAILED="${ALLOW_SQL_ENDPOINT_FAILED:-false}"

FABRIC_API="https://api.fabric.microsoft.com/v1"
ONELAKE_DFS_BASE="https://onelake.dfs.fabric.microsoft.com"

SEED_DIR="$REPO_ROOT/demo-data/lakehouse"
AGENT_TEMPLATE_DIR="$REPO_ROOT/demo-fabric-artifacts/DA_PII_Sentry.DataAgent"

TABLE_FILES=(
  "pii_data_categories.csv"
  "phi_data_categories.csv"
  "data_handling_requirements.csv"
  "compliance_controls.csv"
  "application_systems.csv"
  "data_flows.csv"
)

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: Required command not found: $cmd"
    exit 1
  fi
}

resolve_output() {
  local env_name="$1"
  local tf_output_name="$2"
  local current="${!env_name:-}"
  if [[ -n "$current" ]]; then
    printf '%s' "$current"
    return
  fi

  local output
  output="$($TF_BIN -chdir="$TF_DIR" output -raw "$tf_output_name" 2>/dev/null || true)"
  if [[ -z "$output" || "$output" == "null" ]]; then
    echo "ERROR: Could not resolve $env_name. Set it in env or ensure terraform output '$tf_output_name' exists."
    exit 1
  fi

  printf '%s' "$output"
}

base64_inline() {
  local file_path="$1"
  base64 "$file_path" | tr -d '\r\n'
}

poll_operation() {
  local op_url="$1"
  local max_attempts=120
  local attempt=1

  while (( attempt <= max_attempts )); do
    local body
    body="$(curl -fsSL -H "Authorization: Bearer $FABRIC_TOKEN" "$op_url" || true)"

    if [[ -z "$body" ]]; then
      sleep 2
      ((attempt++))
      continue
    fi

    local status
    status="$($JQ_BIN -r '.status // .state // .operationStatus // ""' <<<"$body")"

    case "$status" in
      Succeeded|Completed)
        return 0
        ;;
      Failed|Cancelled)
        echo "WARN: Long-running operation failed."
        echo "$body"
        return 1
        ;;
      "")
        # Some responses may not include a status once complete.
        return 0
        ;;
      *)
        sleep 5
        ;;
    esac

    ((attempt++))
  done

  echo "ERROR: Timed out waiting for operation: $op_url"
  return 1
}

get_lakehouse_sql_status() {
  local body
  body="$(curl -fsSL -H "Authorization: Bearer $FABRIC_TOKEN" "$FABRIC_API/workspaces/$WORKSPACE_ID/lakehouses/$LAKEHOUSE_ID" || true)"
  if [[ -z "$body" ]]; then
    printf '%s' "Unknown"
    return
  fi

  $JQ_BIN -r '.properties.sqlEndpointProperties.provisioningStatus // "Unknown"' <<<"$body"
}

upload_file_to_onelake() {
  local local_file="$1"
  local remote_name="$2"
  local remote_path="$ONELAKE_DFS_BASE/$WORKSPACE_ID/$LAKEHOUSE_ID/Files/$remote_name"
  local file_size
  file_size="$(wc -c < "$local_file" | tr -d ' ')"

  curl -fsSL -X PUT "$remote_path?resource=file" \
    -H "Authorization: Bearer $STORAGE_TOKEN" \
    -H "x-ms-version: 2021-12-02" \
    -H "Content-Length: 0" \
    >/dev/null

  curl -fsSL -X PATCH "$remote_path?action=append&position=0" \
    -H "Authorization: Bearer $STORAGE_TOKEN" \
    -H "x-ms-version: 2021-12-02" \
    -H "Content-Type: application/octet-stream" \
    --data-binary "@$local_file" \
    >/dev/null

  curl -fsSL -X PATCH "$remote_path?action=flush&position=$file_size" \
    -H "Authorization: Bearer $STORAGE_TOKEN" \
    -H "x-ms-version: 2021-12-02" \
    -H "Content-Length: 0" \
    >/dev/null
}

load_table_from_file() {
  local csv_file="$1"
  local table_name="${csv_file%.csv}"

  local req_body
  req_body="$($JQ_BIN -n \
    --arg rel "Files/$csv_file" \
    '{
      relativePath: $rel,
      pathType: "File",
      mode: "Overwrite",
      recursive: false,
      formatOptions: {
        format: "Csv",
        header: true,
        delimiter: ","
      }
    }'
  )"

  local headers_file
  headers_file="$(mktemp)"

  curl -sS -D "$headers_file" -o /dev/null -X POST \
    "$FABRIC_API/workspaces/$WORKSPACE_ID/lakehouses/$LAKEHOUSE_ID/tables/$table_name/load" \
    -H "Authorization: Bearer $FABRIC_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$req_body"

  local location
  location="$(awk 'tolower($1)=="location:" {print $2}' "$headers_file" | tr -d '\r')"
  local operation_id
  operation_id="$(awk 'tolower($1)=="x-ms-operation-id:" {print $2}' "$headers_file" | tr -d '\r')"
  rm -f "$headers_file"

  if [[ -n "$operation_id" ]]; then
    poll_operation "$FABRIC_API/operations/$operation_id"
  elif [[ -n "$location" ]]; then
    poll_operation "$location"
  fi
}

load_table_with_retry() {
  local csv_file="$1"
  local attempts=4
  local i=1

  while (( i <= attempts )); do
    if load_table_from_file "$csv_file"; then
      return 0
    fi

    if (( i == attempts )); then
      return 1
    fi

    echo "WARN: load failed for ${csv_file%.csv}; retrying (${i}/${attempts})..."
    sleep $((i * 5))
    ((i++))
  done

  return 1
}

build_data_agent_parts() {
  local src_dir="$1"
  local parts='[]'

  while IFS= read -r -d '' file_path; do
    local rel_path="${file_path#"$src_dir"/}"
    local payload
    payload="$(base64_inline "$file_path")"
    parts="$($JQ_BIN -c \
      --arg path "$rel_path" \
      --arg payload "$payload" \
      '. + [{path: $path, payload: $payload, payloadType: "InlineBase64"}]' \
      <<<"$parts")"
  done < <(find "$src_dir" -type f -print0 | sort -z)

  printf '%s' "$parts"
}

upsert_data_agent() {
  local parts_json="$1"

  local existing
  existing="$(curl -fsSL -H "Authorization: Bearer $FABRIC_TOKEN" "$FABRIC_API/workspaces/$WORKSPACE_ID/DataAgents" || true)"

  local existing_id
  existing_id="$($JQ_BIN -r --arg name "$DATA_AGENT_NAME" '(.value // .data // [])[]? | select(.displayName == $name) | .id' <<<"$existing" | head -n 1)"

  if [[ -n "$existing_id" ]]; then
    local update_body
    update_body="$($JQ_BIN -n --argjson parts "$parts_json" '{ definition: { parts: $parts } }')"

    local headers_file
    headers_file="$(mktemp)"

    curl -sS -D "$headers_file" -o /dev/null -X POST \
      "$FABRIC_API/workspaces/$WORKSPACE_ID/DataAgents/$existing_id/updateDefinition?updateMetadata=true" \
      -H "Authorization: Bearer $FABRIC_TOKEN" \
      -H "Content-Type: application/json" \
      -d "$update_body"

    local location
    location="$(awk 'tolower($1)=="location:" {print $2}' "$headers_file" | tr -d '\r')"
    rm -f "$headers_file"

    if [[ -n "$location" ]]; then
      poll_operation "$location"
    fi

    DATA_AGENT_ID="$existing_id"
    return
  fi

  local create_body
  create_body="$($JQ_BIN -n \
    --arg name "$DATA_AGENT_NAME" \
    --arg desc "$DATA_AGENT_DESCRIPTION" \
    --argjson parts "$parts_json" \
    '{
      displayName: $name,
      description: $desc,
      definition: {
        parts: $parts
      }
    }'
  )"

  local create_resp
  create_resp="$(curl -fsSL -X POST \
    "$FABRIC_API/workspaces/$WORKSPACE_ID/DataAgents" \
    -H "Authorization: Bearer $FABRIC_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$create_body")"

  DATA_AGENT_ID="$($JQ_BIN -r '.id // ""' <<<"$create_resp")"

  if [[ -z "$DATA_AGENT_ID" ]]; then
    local refreshed
    refreshed="$(curl -fsSL -H "Authorization: Bearer $FABRIC_TOKEN" "$FABRIC_API/workspaces/$WORKSPACE_ID/DataAgents")"
    DATA_AGENT_ID="$($JQ_BIN -r --arg name "$DATA_AGENT_NAME" '(.value // .data // [])[]? | select(.displayName == $name) | .id' <<<"$refreshed" | head -n 1)"
  fi

  if [[ -z "$DATA_AGENT_ID" ]]; then
    echo "ERROR: Unable to resolve Data Agent ID after create operation."
    exit 1
  fi
}

require_cmd az
require_cmd curl
require_cmd base64

if [[ -n "${TF_BIN:-}" ]]; then
  if [[ ! -f "$TF_BIN" ]]; then
    echo "ERROR: TF_BIN is set but file was not found: $TF_BIN"
    exit 1
  fi
elif command -v terraform >/dev/null 2>&1; then
  TF_BIN="terraform"
elif command -v terraform.exe >/dev/null 2>&1; then
  TF_BIN="terraform.exe"
else
  echo "ERROR: Required command not found: terraform (or terraform.exe)"
  exit 1
fi

if [[ -n "${JQ_BIN:-}" ]]; then
  if [[ ! -f "$JQ_BIN" ]]; then
    echo "ERROR: JQ_BIN is set but file was not found: $JQ_BIN"
    exit 1
  fi
elif command -v jq >/dev/null 2>&1; then
  JQ_BIN="jq"
elif command -v jq.exe >/dev/null 2>&1; then
  JQ_BIN="jq.exe"
else
  echo "ERROR: Required command not found: jq (or jq.exe)"
  exit 1
fi

get_access_token() {
  local resource="$1"
  local scope="$2"

  local token
  token="$(az account get-access-token --resource "$resource" --query accessToken -o tsv 2>/dev/null || true)"
  token="${token%$'\r'}"
  if [[ -n "$token" ]]; then
    printf '%s' "$token"
    return
  fi

  token="$(az account get-access-token --scope "$scope" --query accessToken -o tsv 2>/dev/null || true)"
  token="${token%$'\r'}"
  if [[ -n "$token" ]]; then
    printf '%s' "$token"
    return
  fi

  echo "ERROR: Failed to acquire token for $resource"
  exit 1
}

if [[ ! -d "$SEED_DIR" ]]; then
  echo "ERROR: Seed directory missing: $SEED_DIR"
  exit 1
fi

if [[ ! -d "$AGENT_TEMPLATE_DIR" ]]; then
  echo "ERROR: Data Agent template directory missing: $AGENT_TEMPLATE_DIR"
  exit 1
fi

WORKSPACE_ID="$(resolve_output WORKSPACE_ID fabric_workspace_id)"
LAKEHOUSE_ID="$(resolve_output LAKEHOUSE_ID fabric_lakehouse_id)"

FABRIC_TOKEN="$(get_access_token "https://api.fabric.microsoft.com" "https://api.fabric.microsoft.com/.default")"
STORAGE_TOKEN="$(get_access_token "https://storage.azure.com" "https://storage.azure.com/.default")"

sql_status="$(get_lakehouse_sql_status)"
sql_status="${sql_status%$'\r'}"
if [[ "$sql_status" == "Failed" && "$ALLOW_SQL_ENDPOINT_FAILED" != "true" ]]; then
  echo "ERROR: Lakehouse SQL endpoint provisioning status is 'Failed'."
  echo "Lakehouse ID: $LAKEHOUSE_ID"
  echo "This prevents table load operations in Fabric."
  echo "Set ALLOW_SQL_ENDPOINT_FAILED=true to continue with best-effort agent wiring only."
  exit 1
fi

echo "=== Bootstrap Fabric Ring 1 ==="
echo "Workspace ID : $WORKSPACE_ID"
echo "Lakehouse ID : $LAKEHOUSE_ID"
echo "SQL Status   : $sql_status"
echo "Data Agent   : $DATA_AGENT_NAME"
echo

echo "1/3 Uploading CSV files to OneLake..."
for csv_file in "${TABLE_FILES[@]}"; do
  local_path="$SEED_DIR/$csv_file"
  if [[ ! -f "$local_path" ]]; then
    echo "ERROR: Missing seed file: $local_path"
    exit 1
  fi

  echo " - $csv_file"
  upload_file_to_onelake "$local_path" "$csv_file"
done

if [[ "$SKIP_TABLE_LOADS" == "true" ]]; then
  echo "2/3 Skipping lakehouse table loads (SKIP_TABLE_LOADS=true)."
else
  echo "2/3 Loading CSV files into lakehouse tables..."
  for csv_file in "${TABLE_FILES[@]}"; do
    table_name="${csv_file%.csv}"
    echo " - $table_name"
    if ! load_table_with_retry "$csv_file"; then
      echo "ERROR: Failed to load table '$table_name' after retries."
      exit 1
    fi
  done
fi

echo "3/3 Creating/updating Data Agent definition..."
work_dir="$(mktemp -d)"
cleanup() { rm -rf "$work_dir"; }
trap cleanup EXIT

mkdir -p "$work_dir/agent"
cp -R "$AGENT_TEMPLATE_DIR"/. "$work_dir/agent"

mapfile -t datasource_files < <(find "$work_dir/agent/Files/Config" -type f -name datasource.json | sort)
if (( ${#datasource_files[@]} == 0 )); then
  echo "ERROR: No datasource.json files found under '$work_dir/agent/Files/Config'."
  exit 1
fi

for ds_file in "${datasource_files[@]}"; do
  ds_file="${ds_file%$'\r'}"
  $JQ_BIN \
    --arg ws "$WORKSPACE_ID" \
    --arg lh "$LAKEHOUSE_ID" \
    '.workspaceId = $ws | .artifactId = $lh' \
    < "$ds_file" > "$ds_file.tmp"
  mv "$ds_file.tmp" "$ds_file"
done

parts_json="$(build_data_agent_parts "$work_dir/agent")"
upsert_data_agent "$parts_json"

fabric_connection_target="https://fabric.microsoft.com/groups/$WORKSPACE_ID/aiskills/$DATA_AGENT_ID"

cat > "$AUTO_TFVARS_PATH" <<JSON
{
  "create_fabric_connection": true,
  "fabric_connection_target": "$fabric_connection_target"
}
JSON

echo
echo "Completed successfully."
echo "Fabric Data Agent ID: $DATA_AGENT_ID"
echo "Fabric Connection Target: $fabric_connection_target"
echo "Wrote Terraform auto vars: $AUTO_TFVARS_PATH"
echo ""
echo "Next (Terraform)"
echo "- Re-run terraform apply to create the Foundry Fabric connection"
echo "- Then run ./infra/scripts/create-foundry-agent.sh"
