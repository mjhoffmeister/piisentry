locals {
  base_name     = lower(replace(var.project_name, "-", ""))
  capacity_name = var.capacity_name_override != "" ? var.capacity_name_override : substr("${local.base_name}fabric${var.resource_suffix}", 0, 63)
}

resource "azapi_resource" "fabric_capacity" {
  count = var.create_capacity ? 1 : 0

  type      = "Microsoft.Fabric/capacities@2023-11-01"
  name      = local.capacity_name
  parent_id = var.resource_group_id
  location  = var.capacity_location != "" ? var.capacity_location : var.location

  body = {
    sku = {
      name = var.fabric_capacity_sku
      tier = "Fabric"
    }
    properties = {
      administration = var.admin_object_id != "" ? {
        members = [var.admin_object_id]
      } : null
    }
  }
}

data "fabric_capacity" "target" {
  count = var.create_workspace ? 1 : 0

  display_name = local.capacity_name

  lifecycle {
    postcondition {
      condition     = self.state == "Active"
      error_message = "Fabric capacity must be Active before attaching a workspace."
    }
  }
}

resource "fabric_workspace" "workspace" {
  count = var.create_workspace ? 1 : 0

  display_name = var.workspace_display_name
  description  = "PII Sentry Fabric workspace"
  capacity_id  = data.fabric_capacity.target[0].id
}

resource "fabric_lakehouse" "lakehouse" {
  count = var.create_workspace && var.create_lakehouse ? 1 : 0

  display_name = var.lakehouse_display_name
  description  = "PII Sentry lakehouse"
  workspace_id = fabric_workspace.workspace[0].id
}

resource "fabric_workspace_git" "workspace_git" {
  count = var.create_workspace && var.create_workspace_git ? 1 : 0

  workspace_id            = fabric_workspace.workspace[0].id
  initialization_strategy = var.workspace_git_initialization_strategy

  git_provider_details = {
    git_provider_type = "GitHub"
    owner_name        = var.workspace_git_repository_owner
    repository_name   = var.workspace_git_repository_name
    branch_name       = var.workspace_git_branch_name
    directory_name    = var.workspace_git_directory_name
  }

  git_credentials = {
    source        = "ConfiguredConnection"
    connection_id = var.workspace_git_connection_id
  }
}
