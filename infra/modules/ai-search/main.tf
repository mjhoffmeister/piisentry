locals {
  base_name           = lower(replace(var.project_name, "-", ""))
  search_service_name = substr("${local.base_name}srch${var.resource_suffix}", 0, 60)
}

resource "azapi_resource" "search_service" {
  type      = "Microsoft.Search/searchServices@2024-06-01-preview"
  name      = local.search_service_name
  parent_id = var.resource_group_id
  location  = var.location

  identity {
    type = "SystemAssigned"
  }

  body = {
    sku = {
      name = var.search_sku
    }
    properties = {
      publicNetworkAccess = "Enabled"
      hostingMode         = "default"
      replicaCount        = 1
      partitionCount      = 1
      semanticSearch      = "free"
      authOptions = {
        aadOrApiKey = {
          aadAuthFailureMode = "http401WithBearerChallenge"
        }
      }
    }
  }
}
