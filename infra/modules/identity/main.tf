locals {
  base_name                = lower(replace(var.project_name, "-", ""))
  identity_name            = substr("${local.base_name}-uai-${var.resource_suffix}", 0, 128)
  create_admin_assignments = var.admin_object_id != ""
}

resource "azapi_resource" "user_assigned_identity" {
  type      = "Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31"
  name      = local.identity_name
  parent_id = var.resource_group_id
  location  = var.location

  body = {}
}

resource "azapi_resource" "admin_contributor_on_rg" {
  count = local.create_admin_assignments ? 1 : 0

  type      = "Microsoft.Authorization/roleAssignments@2022-04-01"
  name      = uuidv5("url", "${var.resource_group_id}|${var.admin_object_id}|${var.contributor_role_definition_id}")
  parent_id = var.resource_group_id

  body = {
    properties = {
      principalId      = var.admin_object_id
      principalType    = "User"
      roleDefinitionId = "/subscriptions/${split("/", var.resource_group_id)[2]}/providers/Microsoft.Authorization/roleDefinitions/${var.contributor_role_definition_id}"
    }
  }
}

resource "azapi_resource" "admin_search_contributor" {
  count = local.create_admin_assignments ? 1 : 0

  type      = "Microsoft.Authorization/roleAssignments@2022-04-01"
  name      = uuidv5("url", "${var.search_service_id}|${var.admin_object_id}|${var.search_contributor_role_definition_id}")
  parent_id = var.search_service_id

  body = {
    properties = {
      principalId      = var.admin_object_id
      principalType    = "User"
      roleDefinitionId = "/subscriptions/${split("/", var.search_service_id)[2]}/providers/Microsoft.Authorization/roleDefinitions/${var.search_contributor_role_definition_id}"
    }
  }
}

resource "azapi_resource" "admin_ai_developer" {
  count = local.create_admin_assignments && var.foundry_project_id != "" ? 1 : 0

  type      = "Microsoft.Authorization/roleAssignments@2022-04-01"
  name      = uuidv5("url", "${var.foundry_project_id}|${var.admin_object_id}|${var.ai_developer_role_definition_id}")
  parent_id = var.foundry_project_id

  body = {
    properties = {
      principalId      = var.admin_object_id
      principalType    = "User"
      roleDefinitionId = "/subscriptions/${split("/", var.foundry_project_id)[2]}/providers/Microsoft.Authorization/roleDefinitions/${var.ai_developer_role_definition_id}"
    }
  }
}

resource "azapi_resource" "admin_storage_blob_contributor" {
  count = local.create_admin_assignments ? 1 : 0

  type      = "Microsoft.Authorization/roleAssignments@2022-04-01"
  name      = uuidv5("url", "${var.storage_account_id}|${var.admin_object_id}|${var.storage_blob_data_contributor_role_definition_id}")
  parent_id = var.storage_account_id

  body = {
    properties = {
      principalId      = var.admin_object_id
      principalType    = "User"
      roleDefinitionId = "/subscriptions/${split("/", var.storage_account_id)[2]}/providers/Microsoft.Authorization/roleDefinitions/${var.storage_blob_data_contributor_role_definition_id}"
    }
  }
}

resource "azapi_resource" "admin_search_index_data_reader" {
  count = local.create_admin_assignments ? 1 : 0

  type      = "Microsoft.Authorization/roleAssignments@2022-04-01"
  name      = uuidv5("url", "${var.search_service_id}|${var.admin_object_id}|${var.search_index_data_reader_role_definition_id}")
  parent_id = var.search_service_id

  body = {
    properties = {
      principalId      = var.admin_object_id
      principalType    = "User"
      roleDefinitionId = "/subscriptions/${split("/", var.search_service_id)[2]}/providers/Microsoft.Authorization/roleDefinitions/${var.search_index_data_reader_role_definition_id}"
    }
  }
}

resource "azapi_resource" "admin_azure_ai_user" {
  count = local.create_admin_assignments && var.foundry_account_id != "" ? 1 : 0

  type      = "Microsoft.Authorization/roleAssignments@2022-04-01"
  name      = uuidv5("url", "${var.foundry_account_id}|${var.admin_object_id}|${var.azure_ai_user_role_definition_id}")
  parent_id = var.foundry_account_id

  body = {
    properties = {
      principalId      = var.admin_object_id
      principalType    = "User"
      roleDefinitionId = "/subscriptions/${split("/", var.foundry_account_id)[2]}/providers/Microsoft.Authorization/roleDefinitions/${var.azure_ai_user_role_definition_id}"
    }
  }
}

resource "azapi_resource" "search_blob_reader" {
  count = var.search_service_principal_id != "" ? 1 : 0

  type      = "Microsoft.Authorization/roleAssignments@2022-04-01"
  name      = uuidv5("url", "${var.storage_account_id}|${var.search_service_principal_id}|${var.storage_blob_data_reader_role_definition_id}")
  parent_id = var.storage_account_id

  body = {
    properties = {
      principalId      = var.search_service_principal_id
      principalType    = "ServicePrincipal"
      roleDefinitionId = "/subscriptions/${split("/", var.storage_account_id)[2]}/providers/Microsoft.Authorization/roleDefinitions/${var.storage_blob_data_reader_role_definition_id}"
    }
  }
}

resource "azapi_resource" "search_openai_user" {
  count = var.search_service_principal_id != "" && var.foundry_account_id != "" ? 1 : 0

  type      = "Microsoft.Authorization/roleAssignments@2022-04-01"
  name      = uuidv5("url", "${var.foundry_account_id}|${var.search_service_principal_id}|${var.cognitive_services_openai_user_role_definition_id}")
  parent_id = var.foundry_account_id

  body = {
    properties = {
      principalId      = var.search_service_principal_id
      principalType    = "ServicePrincipal"
      roleDefinitionId = "/subscriptions/${split("/", var.foundry_account_id)[2]}/providers/Microsoft.Authorization/roleDefinitions/${var.cognitive_services_openai_user_role_definition_id}"
    }
  }
}

resource "azapi_resource" "search_cognitive_services_user" {
  count = var.search_service_principal_id != "" && var.foundry_account_id != "" ? 1 : 0

  type      = "Microsoft.Authorization/roleAssignments@2022-04-01"
  name      = uuidv5("url", "${var.foundry_account_id}|${var.search_service_principal_id}|${var.cognitive_services_user_role_definition_id}")
  parent_id = var.foundry_account_id

  body = {
    properties = {
      principalId      = var.search_service_principal_id
      principalType    = "ServicePrincipal"
      roleDefinitionId = "/subscriptions/${split("/", var.foundry_account_id)[2]}/providers/Microsoft.Authorization/roleDefinitions/${var.cognitive_services_user_role_definition_id}"
    }
  }
}

resource "azapi_resource" "project_search_index_data_reader" {
  count = var.foundry_project_id != "" ? 1 : 0

  type      = "Microsoft.Authorization/roleAssignments@2022-04-01"
  name      = uuidv5("url", "${var.search_service_id}|${var.foundry_project_principal_id}|${var.search_index_data_reader_role_definition_id}")
  parent_id = var.search_service_id

  body = {
    properties = {
      principalId      = var.foundry_project_principal_id
      principalType    = "ServicePrincipal"
      roleDefinitionId = "/subscriptions/${split("/", var.search_service_id)[2]}/providers/Microsoft.Authorization/roleDefinitions/${var.search_index_data_reader_role_definition_id}"
    }
  }
}

resource "azapi_resource" "project_search_index_data_contributor" {
  count = var.foundry_project_id != "" ? 1 : 0

  type      = "Microsoft.Authorization/roleAssignments@2022-04-01"
  name      = uuidv5("url", "${var.search_service_id}|${var.foundry_project_principal_id}|${var.search_index_data_contributor_role_definition_id}")
  parent_id = var.search_service_id

  body = {
    properties = {
      principalId      = var.foundry_project_principal_id
      principalType    = "ServicePrincipal"
      roleDefinitionId = "/subscriptions/${split("/", var.search_service_id)[2]}/providers/Microsoft.Authorization/roleDefinitions/${var.search_index_data_contributor_role_definition_id}"
    }
  }
}
