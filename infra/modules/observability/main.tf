locals {
  base_name      = lower(replace(var.project_name, "-", ""))
  workspace_name = substr("${local.base_name}-law-${var.resource_suffix}", 0, 63)
  appi_name      = substr("${local.base_name}-appi-${var.resource_suffix}", 0, 255)
}

resource "azapi_resource" "log_analytics_workspace" {
  type      = "Microsoft.OperationalInsights/workspaces@2023-09-01"
  name      = local.workspace_name
  parent_id = var.resource_group_id
  location  = var.location

  body = {
    properties = {
      sku = {
        name = "PerGB2018"
      }
      retentionInDays                 = 30
      publicNetworkAccessForIngestion = "Enabled"
      publicNetworkAccessForQuery     = "Enabled"
    }
  }
}

resource "azapi_resource" "application_insights" {
  type      = "Microsoft.Insights/components@2020-02-02"
  name      = local.appi_name
  parent_id = var.resource_group_id
  location  = var.location

  body = {
    kind = "web"
    properties = {
      Application_Type    = "web"
      WorkspaceResourceId = azapi_resource.log_analytics_workspace.id
    }
  }
}
