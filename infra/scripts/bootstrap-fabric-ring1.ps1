<#
.SYNOPSIS
    Bootstrap Phase 2 Ring 1 (Fabric IQ) assets in an idempotent way.

.DESCRIPTION
    1) Uploads lakehouse CSV seed files to OneLake Files/
    2) Loads/overwrites six lakehouse tables from those CSVs (optional)
    3) Creates or updates the Data Agent definition from demo-fabric-artifacts

.PARAMETER TfDir
    Terraform directory used to resolve outputs when IDs are not passed.

.PARAMETER WorkspaceId
    Fabric workspace ID. If omitted, resolved from terraform output fabric_workspace_id.

.PARAMETER LakehouseId
    Fabric lakehouse ID. If omitted, resolved from terraform output fabric_lakehouse_id.

.PARAMETER DataAgentName
    Fabric Data Agent display name.

.PARAMETER DataAgentDescription
    Fabric Data Agent description.

.PARAMETER AutoTfvarsPath
    Path to auto tfvars JSON to write fabric connection target into.

.PARAMETER SkipTableLoads
    Skip table load operations and only upload files + upsert agent.

.PARAMETER AllowSqlEndpointFailed
    Continue when lakehouse SQL endpoint is in Failed state.

.EXAMPLE
    .\infra\scripts\bootstrap-fabric-ring1.ps1 -SkipTableLoads -AllowSqlEndpointFailed
#>
[CmdletBinding()]
param(
    [string]$TfDir,
    [string]$WorkspaceId,
    [string]$LakehouseId,
    [string]$DataAgentName = 'DA_PII_Sentry',
    [string]$DataAgentDescription = 'PII Sentry Fabric data agent',
    [string]$AutoTfvarsPath,
    [switch]$SkipTableLoads,
    [switch]$AllowSqlEndpointFailed
)

$ErrorActionPreference = 'Stop'

$scriptDir = (Resolve-Path $PSScriptRoot).Path
$repoRoot = (Resolve-Path (Join-Path $scriptDir '..\..')).Path
if (-not $TfDir) { $TfDir = Join-Path $repoRoot 'infra' }
if (-not $AutoTfvarsPath) { $AutoTfvarsPath = Join-Path $TfDir 'auto.fabric-connection.auto.tfvars.json' }

$fabricApiBase = 'https://api.fabric.microsoft.com/v1'
$oneLakeDfsBase = 'https://onelake.dfs.fabric.microsoft.com'
$seedDir = Join-Path $repoRoot 'demo-data\lakehouse'
$agentTemplateDir = Join-Path $repoRoot 'demo-fabric-artifacts\DA_PII_Sentry.DataAgent'

$tableFiles = @(
    'pii_data_categories.csv',
    'phi_data_categories.csv',
    'data_handling_requirements.csv',
    'compliance_controls.csv',
    'application_systems.csv',
    'data_flows.csv'
)

function Get-BoolFromEnv {
    param(
        [string]$Name,
        [bool]$Default = $false
    )

    $raw = [Environment]::GetEnvironmentVariable($Name)
    if ([string]::IsNullOrWhiteSpace($raw)) { return $Default }
    return $raw.Trim().ToLowerInvariant() -eq 'true'
}

if (-not $PSBoundParameters.ContainsKey('SkipTableLoads')) {
    $SkipTableLoads = Get-BoolFromEnv -Name 'SKIP_TABLE_LOADS' -Default $false
}
if (-not $PSBoundParameters.ContainsKey('AllowSqlEndpointFailed')) {
    $AllowSqlEndpointFailed = Get-BoolFromEnv -Name 'ALLOW_SQL_ENDPOINT_FAILED' -Default $false
}

function Require-Command {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command not found: $Name"
    }
}

function Resolve-Output {
    param(
        [string]$Value,
        [string]$TerraformOutputName,
        [string]$FriendlyName
    )

    if (-not [string]::IsNullOrWhiteSpace($Value)) {
        return $Value.Trim()
    }

    $resolved = terraform -chdir="$TfDir" output -raw $TerraformOutputName 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($resolved) -or $resolved.Trim() -eq 'null') {
        throw "Could not resolve $FriendlyName. Pass -$FriendlyName or ensure terraform output '$TerraformOutputName' exists."
    }

    return $resolved.Trim()
}

function Get-AccessToken {
    param([string]$Resource)

    $token = az account get-access-token --resource $Resource --query accessToken -o tsv 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($token)) {
        throw "Failed to acquire token for $Resource"
    }

    return $token.Trim()
}

function Invoke-FabricJson {
    param(
        [ValidateSet('GET', 'POST')]
        [string]$Method,
        [string]$Uri,
        [string]$Token,
        [object]$Body,
        [switch]$ReturnRawResponse
    )

    $headers = @{ Authorization = "Bearer $Token" }
    $bodyJson = $null
    if ($null -ne $Body) {
        $headers['Content-Type'] = 'application/json'
        $bodyJson = ($Body | ConvertTo-Json -Depth 100 -Compress)
    }

    if ($ReturnRawResponse) {
        if ($null -ne $bodyJson) {
            return Invoke-WebRequest -Method $Method -Uri $Uri -Headers $headers -Body $bodyJson -ErrorAction Stop
        }
        return Invoke-WebRequest -Method $Method -Uri $Uri -Headers $headers -ErrorAction Stop
    }

    if ($null -ne $bodyJson) {
        return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $headers -Body $bodyJson -ErrorAction Stop
    }
    return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $headers -ErrorAction Stop
}

function Poll-Operation {
    param(
        [string]$OperationUri,
        [string]$Token
    )

    $maxAttempts = 120
    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        try {
            $body = Invoke-RestMethod -Method GET -Uri $OperationUri -Headers @{ Authorization = "Bearer $Token" } -ErrorAction Stop
        }
        catch {
            Start-Sleep -Seconds 2
            continue
        }

        if ($null -eq $body) {
            Start-Sleep -Seconds 2
            continue
        }

        $status = @($body.status, $body.state, $body.operationStatus | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })[0]
        if ([string]::IsNullOrWhiteSpace($status)) {
            return
        }

        switch ($status) {
            'Succeeded' { return }
            'Completed' { return }
            'Failed' {
                throw "Long-running operation failed: $($body | ConvertTo-Json -Depth 20 -Compress)"
            }
            'Cancelled' {
                throw "Long-running operation cancelled: $($body | ConvertTo-Json -Depth 20 -Compress)"
            }
            default {
                Start-Sleep -Seconds 5
            }
        }
    }

    throw "Timed out waiting for operation: $OperationUri"
}

function Get-LakehouseSqlStatus {
    param(
        [string]$WorkspaceId,
        [string]$LakehouseId,
        [string]$FabricToken
    )

    try {
        $resp = Invoke-FabricJson -Method GET -Uri "$fabricApiBase/workspaces/$WorkspaceId/lakehouses/$LakehouseId" -Token $FabricToken
    }
    catch {
        return 'Unknown'
    }

    $status = $resp.properties.sqlEndpointProperties.provisioningStatus
    if ([string]::IsNullOrWhiteSpace($status)) { return 'Unknown' }
    return $status
}

function Upload-FileToOneLake {
    param(
        [string]$LocalFile,
        [string]$RemoteName,
        [string]$WorkspaceId,
        [string]$LakehouseId,
        [string]$StorageToken
    )

    $workspaceIdSafe = $WorkspaceId.Trim()
    $lakehouseIdSafe = $LakehouseId.Trim()
    $encodedRemoteName = [System.Uri]::EscapeDataString($RemoteName.Trim())
    $baseUri = ('{0}/{1}/{2}/Files/{3}' -f $oneLakeDfsBase.TrimEnd('/'), $workspaceIdSafe, $lakehouseIdSafe, $encodedRemoteName)
    $createUri = [System.Uri]::new($baseUri + '?resource=file')
    $appendUri = [System.Uri]::new($baseUri + '?action=append&position=0')
    $flushUri = [System.Uri]::new($baseUri + '?action=flush&position=0')
    $headers = @{
        Authorization = "Bearer $StorageToken"
        'x-ms-version' = '2021-12-02'
    }
    $createHeaders = @{
        Authorization = "Bearer $StorageToken"
        'x-ms-version' = '2021-12-02'
        'Content-Length' = '0'
    }
    $flushHeaders = @{
        Authorization = "Bearer $StorageToken"
        'x-ms-version' = '2021-12-02'
        'Content-Length' = '0'
    }

    Invoke-WebRequest -Method Put -Uri $createUri -Headers $createHeaders -ErrorAction Stop | Out-Null

    $bytes = [System.IO.File]::ReadAllBytes($LocalFile)
    $appendHeaders = $headers.Clone()
    $appendHeaders['Content-Type'] = 'application/octet-stream'
    Invoke-WebRequest -Method Patch -Uri $appendUri -Headers $appendHeaders -Body $bytes -ErrorAction Stop | Out-Null

    $flushUri = [System.Uri]::new($baseUri + "?action=flush&position=$($bytes.Length)")
    Invoke-WebRequest -Method Patch -Uri $flushUri -Headers $flushHeaders -ErrorAction Stop | Out-Null
}

function Load-TableFromFile {
    param(
        [string]$CsvFile,
        [string]$WorkspaceId,
        [string]$LakehouseId,
        [string]$FabricToken
    )

    $tableName = [System.IO.Path]::GetFileNameWithoutExtension($CsvFile)
    $body = @{
        relativePath = "Files/$CsvFile"
        pathType = 'File'
        mode = 'Overwrite'
        recursive = $false
        formatOptions = @{
            format = 'Csv'
            header = $true
            delimiter = ','
        }
    }

    $resp = Invoke-FabricJson -Method POST -Uri "$fabricApiBase/workspaces/$WorkspaceId/lakehouses/$LakehouseId/tables/$tableName/load" -Token $FabricToken -Body $body -ReturnRawResponse

    $operationId = $resp.Headers['x-ms-operation-id']
    $location = $resp.Headers['Location']

    if (-not [string]::IsNullOrWhiteSpace($operationId)) {
        Poll-Operation -OperationUri "$fabricApiBase/operations/$operationId" -Token $FabricToken
    }
    elseif (-not [string]::IsNullOrWhiteSpace($location)) {
        Poll-Operation -OperationUri $location -Token $FabricToken
    }
}

function Load-TableWithRetry {
    param(
        [string]$CsvFile,
        [string]$WorkspaceId,
        [string]$LakehouseId,
        [string]$FabricToken
    )

    $attempts = 4
    for ($i = 1; $i -le $attempts; $i++) {
        try {
            Load-TableFromFile -CsvFile $CsvFile -WorkspaceId $WorkspaceId -LakehouseId $LakehouseId -FabricToken $FabricToken
            return
        }
        catch {
            if ($i -eq $attempts) { throw }
            Write-Warning "Load failed for $([System.IO.Path]::GetFileNameWithoutExtension($CsvFile)); retrying ($i/$attempts)..."
            Start-Sleep -Seconds (5 * $i)
        }
    }
}

function Build-DataAgentParts {
    param([string]$SourceDir)

    $files = Get-ChildItem -Path $SourceDir -File -Recurse | Sort-Object FullName
    $parts = @()

    foreach ($file in $files) {
        $relativePath = $file.FullName.Substring($SourceDir.Length).TrimStart([char[]]@([char]92, [char]47)) -replace '\\', '/'
        $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
        $payload = [System.Convert]::ToBase64String($bytes)

        $parts += @{
            path = $relativePath
            payload = $payload
            payloadType = 'InlineBase64'
        }
    }

    return $parts
}

function Resolve-ExistingDataAgentId {
    param(
        [object]$ListResponse,
        [string]$Name
    )

    $items = @()
    if ($ListResponse.PSObject.Properties.Name -contains 'value') { $items = @($ListResponse.value) }
    elseif ($ListResponse.PSObject.Properties.Name -contains 'data') { $items = @($ListResponse.data) }

    foreach ($item in $items) {
        if ($item.displayName -eq $Name) {
            return [string]$item.id
        }
    }

    return $null
}

function Upsert-DataAgent {
    param(
        [object[]]$Parts,
        [string]$WorkspaceId,
        [string]$DataAgentName,
        [string]$DataAgentDescription,
        [string]$FabricToken
    )

    $listUri = "$fabricApiBase/workspaces/$WorkspaceId/DataAgents"
    $existing = Invoke-FabricJson -Method GET -Uri $listUri -Token $FabricToken
    $existingId = Resolve-ExistingDataAgentId -ListResponse $existing -Name $DataAgentName

    if (-not [string]::IsNullOrWhiteSpace($existingId)) {
        $updateBody = @{ definition = @{ parts = $Parts } }
        $resp = Invoke-FabricJson -Method POST -Uri "$fabricApiBase/workspaces/$WorkspaceId/DataAgents/$existingId/updateDefinition?updateMetadata=true" -Token $FabricToken -Body $updateBody -ReturnRawResponse

        $location = $resp.Headers['Location']
        if (-not [string]::IsNullOrWhiteSpace($location)) {
            Poll-Operation -OperationUri $location -Token $FabricToken
        }

        return $existingId
    }

    $createBody = @{
        displayName = $DataAgentName
        description = $DataAgentDescription
        definition = @{ parts = $Parts }
    }

    $created = Invoke-FabricJson -Method POST -Uri $listUri -Token $FabricToken -Body $createBody
    $id = [string]$created.id
    if (-not [string]::IsNullOrWhiteSpace($id)) {
        return $id
    }

    $refreshed = Invoke-FabricJson -Method GET -Uri $listUri -Token $FabricToken
    $resolved = Resolve-ExistingDataAgentId -ListResponse $refreshed -Name $DataAgentName
    if ([string]::IsNullOrWhiteSpace($resolved)) {
        throw 'Unable to resolve Data Agent ID after create operation.'
    }

    return $resolved
}

Require-Command -Name az
Require-Command -Name terraform

if (-not (Test-Path $seedDir -PathType Container)) {
    throw "Seed directory missing: $seedDir"
}
if (-not (Test-Path $agentTemplateDir -PathType Container)) {
    throw "Data Agent template directory missing: $agentTemplateDir"
}

$WorkspaceId = Resolve-Output -Value $WorkspaceId -TerraformOutputName 'fabric_workspace_id' -FriendlyName 'WorkspaceId'
$LakehouseId = Resolve-Output -Value $LakehouseId -TerraformOutputName 'fabric_lakehouse_id' -FriendlyName 'LakehouseId'

$fabricToken = Get-AccessToken -Resource 'https://api.fabric.microsoft.com'
$storageToken = Get-AccessToken -Resource 'https://storage.azure.com'

$sqlStatus = Get-LakehouseSqlStatus -WorkspaceId $WorkspaceId -LakehouseId $LakehouseId -FabricToken $fabricToken
if ($sqlStatus -eq 'Failed' -and -not $AllowSqlEndpointFailed) {
    throw "Lakehouse SQL endpoint provisioning status is 'Failed'. Use -AllowSqlEndpointFailed to continue with best-effort agent wiring only."
}

Write-Host '=== Bootstrap Fabric Ring 1 ==='
Write-Host "Workspace ID : $WorkspaceId"
Write-Host "Lakehouse ID : $LakehouseId"
Write-Host "SQL Status   : $sqlStatus"
Write-Host "Data Agent   : $DataAgentName"
Write-Host ''

Write-Host '1/3 Uploading CSV files to OneLake...'
foreach ($csv in $tableFiles) {
    $localPath = Join-Path $seedDir $csv
    if (-not (Test-Path $localPath -PathType Leaf)) {
        throw "Missing seed file: $localPath"
    }

    Write-Host " - $csv"
    Upload-FileToOneLake -LocalFile $localPath -RemoteName $csv -WorkspaceId $WorkspaceId -LakehouseId $LakehouseId -StorageToken $storageToken
}

if ($SkipTableLoads) {
    Write-Host '2/3 Skipping lakehouse table loads (SkipTableLoads=true).'
}
else {
    Write-Host '2/3 Loading CSV files into lakehouse tables...'
    foreach ($csv in $tableFiles) {
        Write-Host " - $([System.IO.Path]::GetFileNameWithoutExtension($csv))"
        Load-TableWithRetry -CsvFile $csv -WorkspaceId $WorkspaceId -LakehouseId $LakehouseId -FabricToken $fabricToken
    }
}

Write-Host '3/3 Creating/updating Data Agent definition...'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("piisentry-agent-" + [System.Guid]::NewGuid().ToString('N'))
$null = New-Item -Path $tempRoot -ItemType Directory -Force
$agentWorkDir = Join-Path $tempRoot 'agent'
$null = New-Item -Path $agentWorkDir -ItemType Directory -Force

try {
    Copy-Item -Path (Join-Path $agentTemplateDir '*') -Destination $agentWorkDir -Recurse -Force

    $datasourceFiles = Get-ChildItem -Path (Join-Path $agentWorkDir 'Files\Config') -Filter 'datasource.json' -File -Recurse
    if ($datasourceFiles.Count -eq 0) {
        throw "No datasource.json files found under '$agentWorkDir\\Files\\Config'."
    }

    foreach ($ds in $datasourceFiles) {
        $doc = Get-Content -Path $ds.FullName -Raw | ConvertFrom-Json
        $doc.workspaceId = $WorkspaceId
        $doc.artifactId = $LakehouseId
        $doc | ConvertTo-Json -Depth 100 | Set-Content -Path $ds.FullName -Encoding UTF8NoBOM
    }

    $parts = Build-DataAgentParts -SourceDir $agentWorkDir
    $dataAgentId = Upsert-DataAgent -Parts $parts -WorkspaceId $WorkspaceId -DataAgentName $DataAgentName -DataAgentDescription $DataAgentDescription -FabricToken $fabricToken

    $fabricConnectionTarget = "https://fabric.microsoft.com/groups/$WorkspaceId/aiskills/$dataAgentId"
    $tfvarsObj = [ordered]@{
        create_fabric_connection = $true
        fabric_connection_target = $fabricConnectionTarget
    }
    $tfvarsObj | ConvertTo-Json -Depth 10 | Set-Content -Path $AutoTfvarsPath -Encoding UTF8NoBOM

    Write-Host ''
    Write-Host 'Completed successfully.'
    Write-Host "Fabric Data Agent ID: $dataAgentId"
    Write-Host "Fabric Connection Target: $fabricConnectionTarget"
    Write-Host "Wrote Terraform auto vars: $AutoTfvarsPath"
    Write-Host ''
    Write-Host 'Next (Terraform)'
    Write-Host '- Re-run terraform apply to create the Foundry Fabric connection'
    Write-Host '- Then run ./infra/scripts/create-foundry-agent.sh'
}
finally {
    if (Test-Path $tempRoot) {
        Remove-Item -Path $tempRoot -Recurse -Force
    }
}
