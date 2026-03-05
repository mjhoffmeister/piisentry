terraform {
  required_version = ">= 1.8.0"

  required_providers {
    azapi = {
      source  = "azure/azapi"
      version = "~> 2.8.0"
    }
    fabric = {
      source  = "microsoft/fabric"
      version = "~> 1.8.0"
    }
  }
}

provider "azapi" {}

provider "fabric" {
  preview = true
  use_cli = true
}

data "azapi_client_config" "current" {}

locals {
  resource_group_name = "${var.project_name}-rg"
}

resource "azapi_resource" "resource_group" {
  type      = "Microsoft.Resources/resourceGroups@2024-03-01"
  name      = local.resource_group_name
  location  = var.location
  parent_id = "/subscriptions/${data.azapi_client_config.current.subscription_id}"

  body = {}
}

module "ai_search" {
  source = "./modules/ai-search"

  resource_group_id = azapi_resource.resource_group.id
  location          = var.location
  project_name      = var.project_name
  resource_suffix   = var.resource_suffix
  search_sku        = var.search_sku
}

module "ai_foundry" {
  source = "./modules/ai-foundry"

  resource_group_id                 = azapi_resource.resource_group.id
  location                          = var.location
  project_name                      = var.project_name
  resource_suffix                   = var.resource_suffix
  foundry_sku                       = var.foundry_sku
  foundry_user_assigned_identity_id = module.identity.user_assigned_identity_id
  create_project                    = var.create_foundry_project
  create_fabric_connection          = var.create_fabric_connection
  fabric_connection_target          = var.fabric_connection_target
  fabric_workspace_id               = var.fabric_workspace_id
  fabric_data_agent_id              = var.fabric_data_agent_id
  create_embedding_deployment       = var.create_embedding_deployment
  create_chat_deployment            = var.create_chat_deployment
  create_bing_search                = var.create_bing_search
  bing_api_key                      = var.bing_api_key
}

module "storage" {
  source = "./modules/storage"

  resource_group_id = azapi_resource.resource_group.id
  location          = var.location
  project_name      = var.project_name
  resource_suffix   = var.resource_suffix
}

module "observability" {
  source = "./modules/observability"

  resource_group_id = azapi_resource.resource_group.id
  location          = var.location
  project_name      = var.project_name
  resource_suffix   = var.resource_suffix
}

module "fabric" {
  source = "./modules/fabric"

  resource_group_id                     = azapi_resource.resource_group.id
  location                              = var.fabric_location != "" ? var.fabric_location : var.location
  project_name                          = var.project_name
  resource_suffix                       = var.resource_suffix
  fabric_capacity_sku                   = var.fabric_capacity_sku
  admin_object_id                       = var.fabric_admin_object_id
  capacity_name_override                = var.fabric_capacity_name_override
  capacity_location                     = var.fabric_capacity_location
  create_capacity                       = var.create_fabric_capacity
  create_workspace                      = var.create_fabric_workspace
  workspace_display_name                = var.fabric_workspace_display_name
  create_lakehouse                      = var.create_fabric_lakehouse
  lakehouse_display_name                = var.fabric_lakehouse_display_name
  create_workspace_git                  = var.create_fabric_workspace_git
  workspace_git_repository_owner        = var.fabric_workspace_git_repository_owner
  workspace_git_repository_name         = var.fabric_workspace_git_repository_name
  workspace_git_branch_name             = var.fabric_workspace_git_branch_name
  workspace_git_directory_name          = var.fabric_workspace_git_directory_name
  workspace_git_connection_id           = var.fabric_workspace_git_connection_id
  workspace_git_initialization_strategy = var.fabric_workspace_git_initialization_strategy
}

module "identity" {
  source = "./modules/identity"

  resource_group_id = azapi_resource.resource_group.id
  location          = var.location
  project_name      = var.project_name
  resource_suffix   = var.resource_suffix
  admin_object_id   = var.admin_object_id

  foundry_project_id           = module.ai_foundry.foundry_project_id
  search_service_id            = module.ai_search.search_service_id
  search_service_principal_id  = module.ai_search.search_service_principal_id
  storage_account_id           = module.storage.storage_account_id
  foundry_account_id           = module.ai_foundry.foundry_account_id
  foundry_project_principal_id = module.ai_foundry.foundry_project_principal_id
}
