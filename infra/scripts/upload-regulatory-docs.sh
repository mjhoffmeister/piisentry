#!/usr/bin/env bash
set -euo pipefail

# Upload regulatory text files to the Azure Blob Storage container
# used by Foundry IQ (AI Search) for vector indexing.
#
# Prerequisites:
#   - az CLI authenticated (az login)
#   - Terraform has been applied (storage account + regulatory container exist)
#
# Usage:
#   STORAGE_ACCOUNT=piisentryste77989ed ./infra/scripts/upload-regulatory-docs.sh
#   — or —
#   The script reads the storage account name from terraform output if not set.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONTAINER_NAME="regulatory"

# Resolve regulatory dir as a Windows path when running under Git Bash / MSYS
REGULATORY_DIR="$REPO_ROOT/demo-data/regulatory"
if command -v cygpath &>/dev/null; then
	REGULATORY_DIR="$(cygpath -w "$REGULATORY_DIR")"
fi

if [[ -z "${STORAGE_ACCOUNT:-}" ]]; then
	echo "STORAGE_ACCOUNT not set; reading from terraform output..."
	STORAGE_ACCOUNT="$(terraform -chdir="$REPO_ROOT/infra" output -raw storage_account_name 2>/dev/null || true)"
fi

if [[ -z "$STORAGE_ACCOUNT" ]]; then
	echo "ERROR: Could not determine storage account name."
	echo "Set STORAGE_ACCOUNT env var or ensure 'terraform output storage_account_name' works."
	exit 1
fi

if [[ ! -d "$REPO_ROOT/demo-data/regulatory" ]]; then
	echo "ERROR: Regulatory data directory not found: $REPO_ROOT/demo-data/regulatory"
	exit 1
fi

file_count=0
for f in "$REPO_ROOT/demo-data/regulatory"/*.txt; do
	[[ -f "$f" ]] || continue
	blob_name="$(basename "$f")"
	upload_path="$f"
	if command -v cygpath &>/dev/null; then
		upload_path="$(cygpath -w "$f")"
	fi
	echo "Uploading $blob_name -> $STORAGE_ACCOUNT/$CONTAINER_NAME ..."
	az storage blob upload \
		--account-name "$STORAGE_ACCOUNT" \
		--container-name "$CONTAINER_NAME" \
		--name "$blob_name" \
		--file "$upload_path" \
		--overwrite \
		--auth-mode login \
		--only-show-errors
	file_count=$((file_count + 1))
done

if [[ $file_count -eq 0 ]]; then
	echo "WARNING: No .txt files found in $REGULATORY_DIR"
	exit 1
fi

echo "Uploaded $file_count file(s) to $STORAGE_ACCOUNT/$CONTAINER_NAME."
