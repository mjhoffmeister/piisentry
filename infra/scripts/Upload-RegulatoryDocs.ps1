<#
.SYNOPSIS
    Upload regulatory text files to Azure Blob Storage.

.DESCRIPTION
    Uploads all .txt files from demo-data/regulatory/ to the 'regulatory'
    container in the provisioned storage account.

.PARAMETER StorageAccount
    Storage account name. If omitted, reads from terraform output.

.EXAMPLE
    .\infra\scripts\Upload-RegulatoryDocs.ps1
    .\infra\scripts\Upload-RegulatoryDocs.ps1 -StorageAccount piisentryste77989ed
#>
[CmdletBinding()]
param(
    [string]$StorageAccount
)

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path "$PSScriptRoot\..\..").Path
$regulatoryDir = Join-Path $repoRoot 'demo-data\regulatory'
$containerName = 'regulatory'

# Resolve storage account name
if (-not $StorageAccount) {
    Write-Host 'StorageAccount not specified; reading from terraform output...'
    $StorageAccount = terraform -chdir="$repoRoot\infra" output -raw storage_account_name 2>$null
}
if (-not $StorageAccount) {
    Write-Error 'Could not determine storage account name. Pass -StorageAccount or ensure terraform output storage_account_name works.'
}

if (-not (Test-Path $regulatoryDir)) {
    Write-Error "Regulatory data directory not found: $regulatoryDir"
}

$files = Get-ChildItem -Path $regulatoryDir -Filter '*.txt'
if ($files.Count -eq 0) {
    Write-Error "No .txt files found in $regulatoryDir"
}

foreach ($f in $files) {
    Write-Host "Uploading $($f.Name) -> $StorageAccount/$containerName ..."
    az storage blob upload `
        --account-name $StorageAccount `
        --container-name $containerName `
        --name $f.Name `
        --file $f.FullName `
        --overwrite `
        --auth-mode login `
        --only-show-errors
    if ($LASTEXITCODE -ne 0) { throw "Failed to upload $($f.Name)" }
}

Write-Host "`nUploaded $($files.Count) file(s) to $StorageAccount/$containerName."
