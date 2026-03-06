<#
.SYNOPSIS
    Ensures the Fabric SQL endpoint can access its Customer-Managed Key (CMK) in Key Vault.

.DESCRIPTION
    MCAPS and enterprise subscriptions often enforce CMK encryption on Fabric SQL endpoints
    via Azure Policy. When the Fabric capacity is paused/resumed or the Key Vault has public
    access disabled, the SQL endpoint loses its encryption key connection.

    This script:
    1. Finds the Key Vault used by the Fabric workspace (West US 2 region)
    2. Enables public network access on the Key Vault (if disabled by policy)
    3. Grants Key Vault Crypto User to the admin account
    4. Grants Key Vault Crypto User to the Power BI Service principal (Fabric's internal identity)
    5. Verifies SQL endpoint connectivity

.PARAMETER SubscriptionId
    Azure subscription ID.

.PARAMETER ResourceGroup
    Resource group containing the Key Vault (may differ from Fabric RG).

.PARAMETER KeyVaultName
    Name of the Key Vault holding the CMK.

.PARAMETER AdminUpn
    UPN of the admin account (e.g. admin@tenant.onmicrosoft.com).

.PARAMETER SqlEndpoint
    Fabric SQL endpoint connection string (from lakehouse properties).

.PARAMETER DatabaseName
    Lakehouse database name for connectivity test.

.EXAMPLE
    .\Setup-FabricAuth.ps1 `
        -SubscriptionId "c94297dc-12b3-40c7-a773-64846b40a34c" `
        -ResourceGroup "rg-dev" `
        -KeyVaultName "kv-artisticowl" `
        -AdminUpn "admin@MngEnvMCAP743474.onmicrosoft.com" `
        -SqlEndpoint "d6srgch5j2le7o2boy4bslr2pi-5blnfmdzqcmedn37dlpcolw4ge.datawarehouse.fabric.microsoft.com" `
        -DatabaseName "LH_PII_Sentry_02"
#>
param(
    [Parameter(Mandatory)] [string] $SubscriptionId,
    [Parameter(Mandatory)] [string] $ResourceGroup,
    [Parameter(Mandatory)] [string] $KeyVaultName,
    [Parameter(Mandatory)] [string] $AdminUpn,
    [string] $SqlEndpoint,
    [string] $DatabaseName
)

$ErrorActionPreference = "Stop"
$kvScope = "/subscriptions/$SubscriptionId/resourcegroups/$ResourceGroup/providers/microsoft.keyvault/vaults/$KeyVaultName"

# Well-known Power BI / Fabric service principal app ID
$pbiAppId = "00000009-0000-0000-c000-000000000000"

Write-Host "=== Fabric CMK Auth Setup ===" -ForegroundColor Cyan

# Step 1: Enable public network access on Key Vault
Write-Host "Enabling public network access on $KeyVaultName..."
az keyvault update --name $KeyVaultName --public-network-access Enabled --default-action Allow --bypass AzureServices -o none 2>$null
Write-Host "  Done." -ForegroundColor Green

# Step 2: Grant Key Vault Crypto User to admin
Write-Host "Granting Key Vault Crypto User to $AdminUpn..."
az role assignment create --assignee $AdminUpn --role "Key Vault Crypto User" --scope $kvScope -o none 2>$null
Write-Host "  Done." -ForegroundColor Green

# Step 3: Grant Key Vault Crypto User to Power BI Service principal
Write-Host "Granting Key Vault Crypto User to Power BI Service ($pbiAppId)..."
$pbiOid = az ad sp show --id $pbiAppId --query "id" -o tsv 2>$null
if ($pbiOid) {
    az role assignment create --assignee-object-id $pbiOid --assignee-principal-type ServicePrincipal --role "Key Vault Crypto User" --scope $kvScope -o none 2>$null
    Write-Host "  Done (OID: $pbiOid)." -ForegroundColor Green
} else {
    Write-Host "  WARNING: Power BI Service principal not found in tenant." -ForegroundColor Yellow
}

# Step 4: Verify SQL connectivity (optional)
if ($SqlEndpoint -and $DatabaseName) {
    Write-Host "Testing SQL endpoint connectivity..."
    Start-Sleep -Seconds 10

    $token = az account get-access-token --resource "https://database.windows.net" --query accessToken -o tsv 2>$null
    try {
        $conn = New-Object System.Data.SqlClient.SqlConnection
        $conn.ConnectionString = "Server=$SqlEndpoint;Database=$DatabaseName;Encrypt=True;TrustServerCertificate=False"
        $conn.AccessToken = $token
        $conn.Open()

        $cmd = $conn.CreateCommand()
        $cmd.CommandText = "SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES"
        $tableCount = $cmd.ExecuteScalar()
        $conn.Close()

        Write-Host "  Connected! $tableCount tables accessible." -ForegroundColor Green
    }
    catch {
        Write-Host "  SQL connection failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "  The Data Agent may need a capacity cycle (pause/resume) to pick up the new KV permissions." -ForegroundColor Yellow
    }
} else {
    Write-Host "Skipping SQL test (no endpoint/database provided)."
}

Write-Host ""
Write-Host "Setup complete. If the Data Agent still can't access the lakehouse:" -ForegroundColor Cyan
Write-Host "  1. Pause and resume the Fabric capacity"
Write-Host "  2. Remove and re-add the lakehouse datasource in the Data Agent"
Write-Host "  3. Publish the Data Agent"
