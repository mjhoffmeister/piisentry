locals {
  base_name            = lower(replace(var.project_name, "-", ""))
  foundry_account_name = substr("${local.base_name}-foundry-${var.resource_suffix}", 0, 64)
  foundry_project_name = substr("${local.base_name}-proj-${var.resource_suffix}", 0, 64)
  connection_name      = substr("fabric-${var.resource_suffix}", 0, 64)
}

resource "azapi_resource" "foundry_account" {
  type      = "Microsoft.CognitiveServices/accounts@2025-06-01"
  name      = local.foundry_account_name
  parent_id = var.resource_group_id
  location  = var.location

  body = {
    kind = "AIServices"
    identity = var.foundry_user_assigned_identity_id != "" ? {
      type = "SystemAssigned, UserAssigned"
      userAssignedIdentities = {
        (var.foundry_user_assigned_identity_id) = {}
      }
      } : {
      type                   = "SystemAssigned"
      userAssignedIdentities = {}
    }
    sku = {
      name = var.foundry_sku
    }
    properties = {
      allowProjectManagement = true
      publicNetworkAccess    = "Enabled"
      customSubDomainName    = local.foundry_account_name
    }
  }
}

resource "azapi_resource" "foundry_project" {
  count = var.create_project ? 1 : 0

  type      = "Microsoft.CognitiveServices/accounts/projects@2025-06-01"
  name      = local.foundry_project_name
  parent_id = azapi_resource.foundry_account.id
  location  = var.location

  body = {
    identity = {
      type = "SystemAssigned"
    }
    properties = {}
  }

  response_export_values = ["identity.principalId"]
}

resource "azapi_resource" "fabric_connection" {
  count = var.create_project && var.create_fabric_connection ? 1 : 0

  type                      = "Microsoft.CognitiveServices/accounts/connections@2025-06-01"
  name                      = local.connection_name
  parent_id                 = azapi_resource.foundry_account.id
  location                  = var.location
  schema_validation_enabled = false

  body = {
    properties = {
      category      = "Fabric"
      target        = var.fabric_connection_target
      authType      = "AAD"
      isSharedToAll = true
    }
  }
}

resource "azapi_resource" "embedding_deployment" {
  count = var.create_embedding_deployment ? 1 : 0

  type      = "Microsoft.CognitiveServices/accounts/deployments@2024-10-01"
  name      = var.embedding_deployment_name
  parent_id = azapi_resource.foundry_account.id

  body = {
    sku = {
      name     = "Standard"
      capacity = var.embedding_deployment_capacity
    }
    properties = {
      model = {
        format  = "OpenAI"
        name    = var.embedding_model_name
        version = var.embedding_model_version
      }
    }
  }
}

resource "azapi_resource" "chat_deployment" {
  count = var.create_chat_deployment ? 1 : 0

  type      = "Microsoft.CognitiveServices/accounts/deployments@2024-10-01"
  name      = var.chat_deployment_name
  parent_id = azapi_resource.foundry_account.id

  body = {
    sku = {
      name     = var.chat_deployment_sku
      capacity = var.chat_deployment_capacity
    }
    properties = {
      model = {
        format  = "OpenAI"
        name    = var.chat_model_name
        version = var.chat_model_version
      }
    }
  }

  depends_on = [azapi_resource.embedding_deployment]
}

# --- Bing Search (grounding) ---

resource "azapi_resource" "bing_search" {
  count = var.create_bing_search ? 1 : 0

  type                      = "Microsoft.Bing/accounts@2020-06-10"
  name                      = "${local.base_name}-bing-${var.resource_suffix}"
  parent_id                 = var.resource_group_id
  location                  = "global"
  schema_validation_enabled = false

  body = {
    kind = "Bing.Grounding"
    sku = {
      name = var.bing_search_sku
    }
    properties = {}
  }
}

resource "azapi_resource" "bing_connection" {
  count = var.create_bing_search && var.create_project ? 1 : 0

  type                      = "Microsoft.CognitiveServices/accounts/connections@2025-04-01-preview"
  name                      = "${azapi_resource.foundry_account.name}-bingsearchconnection"
  parent_id                 = azapi_resource.foundry_account.id
  location                  = var.location
  schema_validation_enabled = false

  body = {
    properties = {
      category      = "ApiKey"
      target        = "https://api.bing.microsoft.com/"
      authType      = "ApiKey"
      isSharedToAll = true
      credentials = {
        key = var.bing_api_key
      }
      metadata = {
        ApiType    = "Azure"
        Location   = "global"
        ResourceId = azapi_resource.bing_search[0].id
      }
    }
  }
}
