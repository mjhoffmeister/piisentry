<#
.SYNOPSIS
    Create AI Search data source, index, skillset, and indexer for Foundry IQ.

.DESCRIPTION
    Sets up the Azure AI Search pipeline for regulatory document indexing:
      1. Data source connection (blob, managed identity auth)
      2. Index with vector fields
      3. Skillset for text chunking + embedding
      4. Indexer to populate the index
    After the indexer finishes, create the knowledge base in the Foundry portal.

.PARAMETER SearchEndpoint
    AI Search endpoint. If omitted, reads from terraform output.

.PARAMETER StorageAccount
    Storage account name. If omitted, reads from terraform output.

.PARAMETER FoundryProjectEndpoint
    Foundry project endpoint. If omitted, reads from terraform output.

.PARAMETER KnowledgeBaseName
    Name for the knowledge base (informational). Default: piisentry-regulatory-kb

.EXAMPLE
    .\infra\scripts\New-FoundryIqKnowledgeBase.ps1
#>
[CmdletBinding()]
param(
    [string]$SearchEndpoint,
    [string]$StorageAccount,
    [string]$FoundryProjectEndpoint,
    [string]$KnowledgeBaseName = 'regulatory-knowledge-base'
)

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path "$PSScriptRoot\..\..").Path
$containerName = 'regulatory'
$indexName = 'regulatory-index'
$datasourceName = 'regulatory-blob-ds'
$indexerName = 'regulatory-indexer'
$skillsetName = 'regulatory-skillset'
$searchApiVersion = '2024-11-01-preview'

# ---------------------------------------------------------------------------
# Resolve values from params or terraform outputs
# ---------------------------------------------------------------------------
function Resolve-TfOutput([string]$Value, [string]$OutputName) {
    if ($Value) { return $Value }
    $result = terraform -chdir="$repoRoot\infra" output -raw $OutputName 2>$null
    if (-not $result) {
        throw "Could not resolve '$OutputName'. Pass it as a parameter or ensure terraform output works."
    }
    return $result
}

$SearchEndpoint = Resolve-TfOutput $SearchEndpoint 'search_endpoint'
$StorageAccount = Resolve-TfOutput $StorageAccount 'storage_account_name'
$FoundryProjectEndpoint = Resolve-TfOutput $FoundryProjectEndpoint 'foundry_project_endpoint'

# ---------------------------------------------------------------------------
# Auth
# ---------------------------------------------------------------------------
$searchToken = az account get-access-token --resource https://search.azure.com --query accessToken -o tsv
if ($LASTEXITCODE -ne 0) { throw 'Failed to get search access token.' }

$subscriptionId = az account show --query id -o tsv
$storageResourceId = "/subscriptions/$subscriptionId/resourceGroups/piisentry-rg/providers/Microsoft.Storage/storageAccounts/$StorageAccount"

$headers = @{
    'Authorization' = "Bearer $searchToken"
    'Content-Type'  = 'application/json'
}

function Search-Put([string]$path, [object]$body) {
    $url = "$SearchEndpoint$($path)?api-version=$searchApiVersion"
    $json = $body | ConvertTo-Json -Depth 20
    Invoke-RestMethod -Uri $url -Method Put -Headers $headers -Body $json -ContentType 'application/json'
}

function Search-Post([string]$path, [object]$body) {
    $url = "$SearchEndpoint$($path)?api-version=$searchApiVersion"
    $json = if ($body) { $body | ConvertTo-Json -Depth 20 } else { '{}' }
    Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $json -ContentType 'application/json'
}

Write-Host "=== Foundry IQ Knowledge Base Setup ==="
Write-Host "Search endpoint:  $SearchEndpoint"
Write-Host "Storage account:  $StorageAccount"
Write-Host "Knowledge base:   $KnowledgeBaseName"
Write-Host ""

# ---------------------------------------------------------------------------
# 1. Data source connection
# ---------------------------------------------------------------------------
Write-Host "1/5  Creating data source '$datasourceName' ..."
$dsBody = @{
    name = $datasourceName
    type = 'azureblob'
    credentials = @{
        connectionString = "ResourceId=$storageResourceId;"
    }
    container = @{
        name = $containerName
    }
}
Search-Put "/datasources/$datasourceName" $dsBody | Out-Null
Write-Host "     Done."

# ---------------------------------------------------------------------------
# 2. Index with vector profile
# ---------------------------------------------------------------------------
Write-Host "2/5  Creating index '$indexName' ..."
$indexBody = @{
    name = $indexName
    fields = @(
        @{ name = 'chunk_id';    type = 'Edm.String';  key = $true; filterable = $true; sortable = $true; analyzer = 'keyword' }
        @{ name = 'parent_id';   type = 'Edm.String';  filterable = $true }
        @{ name = 'title';       type = 'Edm.String';  searchable = $true }
        @{ name = 'chunk';       type = 'Edm.String';  searchable = $true }
        @{ name = 'text_vector'; type = 'Collection(Edm.Single)'; searchable = $true; dimensions = 1536; vectorSearchProfile = 'default-profile' }
    )
    vectorSearch = @{
        algorithms = @(
            @{ name = 'default-hnsw'; kind = 'hnsw' }
        )
        profiles = @(
            @{
                name = 'default-profile'
                algorithm = 'default-hnsw'
            }
        )
    }
}
Search-Put "/indexes/$indexName" $indexBody | Out-Null
Write-Host "     Done."

# ---------------------------------------------------------------------------
# 3. Skillset
# ---------------------------------------------------------------------------
Write-Host "3/5  Creating skillset '$skillsetName' ..."
$skillsetBody = @{
    name = $skillsetName
    description = 'Chunk regulatory text and generate embeddings via Foundry project.'
    skills = @(
        @{
            '@odata.type' = '#Microsoft.Skills.Text.SplitSkill'
            name = 'split'
            description = 'Split into chunks'
            textSplitMode = 'pages'
            maximumPageLength = 2000
            pageOverlapLength = 200
            context = '/document'
            inputs = @( @{ name = 'text'; source = '/document/content' } )
            outputs = @( @{ name = 'textItems'; targetName = 'pages' } )
        }
        @{
            '@odata.type' = '#Microsoft.Skills.Text.AzureOpenAIEmbeddingSkill'
            name = 'embed'
            description = 'Embed chunks'
            context = '/document/pages/*'
            modelName = 'text-embedding-ada-002'
            deploymentId = 'text-embedding-ada-002'
            resourceUri = "https://piisentry-foundry-dev.openai.azure.com"
            inputs = @( @{ name = 'text'; source = '/document/pages/*' } )
            outputs = @( @{ name = 'embedding'; targetName = 'text_vector' } )
        }
    )
    indexProjections = @{
        selectors = @(
            @{
                targetIndexName = $indexName
                parentKeyFieldName = 'parent_id'
                sourceContext = '/document/pages/*'
                mappings = @(
                    @{ name = 'chunk';       source = '/document/pages/*' }
                    @{ name = 'text_vector'; source = '/document/pages/*/text_vector' }
                    @{ name = 'title';       source = '/document/metadata_storage_name' }
                )
            }
        )
        parameters = @{ projectionMode = 'skipIndexingParentDocuments' }
    }
}
Search-Put "/skillsets/$skillsetName" $skillsetBody | Out-Null
Write-Host "     Done."

# ---------------------------------------------------------------------------
# 4. Indexer
# ---------------------------------------------------------------------------
Write-Host "4/5  Creating indexer '$indexerName' ..."
$indexerBody = @{
    name = $indexerName
    dataSourceName = $datasourceName
    targetIndexName = $indexName
    skillsetName = $skillsetName
    parameters = @{
        configuration = @{
            parsingMode = 'default'
            dataToExtract = 'contentAndMetadata'
        }
    }
}
Search-Put "/indexers/$indexerName" $indexerBody | Out-Null
Write-Host "     Done."

# ---------------------------------------------------------------------------
# 5. Trigger indexer run
# ---------------------------------------------------------------------------
Write-Host "5/5  Running indexer '$indexerName' ..."
try { Search-Post "/indexers/$indexerName/run" $null | Out-Null } catch {}
Write-Host "     Indexer triggered."

Write-Host ""
Write-Host "=== Setup complete ==="
Write-Host ""
Write-Host "NOTE: Knowledge base creation for agentic retrieval is currently"
Write-Host "portal-only in preview. After the indexer finishes, create the"
Write-Host "knowledge base named '$KnowledgeBaseName' in the Foundry portal:"
Write-Host "  1. Open the Foundry project: $FoundryProjectEndpoint"
Write-Host "  2. Go to Knowledge Bases -> Create"
Write-Host "  3. Add a 'blob' knowledge source pointing at index '$indexName'"
Write-Host "  4. (Optional) Add a 'Bing' web knowledge source for real-time lookups"
Write-Host "  5. Name it '$KnowledgeBaseName'"
