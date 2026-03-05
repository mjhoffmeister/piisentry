output "resource_group_id" {
  value       = azapi_resource.resource_group.id
  description = "Resource group resource ID."
}

output "resource_group_name" {
  value       = azapi_resource.resource_group.name
  description = "Resource group name."
}

output "foundry_account_id" {
  value       = module.ai_foundry.foundry_account_id
  description = "Foundry account resource ID."
}

output "foundry_project_id" {
  value       = module.ai_foundry.foundry_project_id
  description = "Foundry project resource ID."
}

output "foundry_project_endpoint" {
  value       = module.ai_foundry.foundry_project_endpoint
  description = "Foundry project endpoint URL."
}

output "fabric_connection_id" {
  value       = module.ai_foundry.fabric_connection_id
  description = "Foundry Fabric connection resource ID."
}

output "search_service_id" {
  value       = module.ai_search.search_service_id
  description = "Azure AI Search service resource ID."
}

output "search_endpoint" {
  value       = module.ai_search.search_endpoint
  description = "Azure AI Search endpoint URL."
}

output "app_insights_connection_string" {
  value       = module.observability.app_insights_connection_string
  description = "Application Insights connection string."
  sensitive   = true
}

output "storage_account_name" {
  value       = module.storage.storage_account_name
  description = "Storage account name."
}

output "user_assigned_identity_id" {
  value       = module.identity.user_assigned_identity_id
  description = "User-assigned managed identity resource ID."
}

output "fabric_workspace_id" {
  value       = module.fabric.fabric_workspace_id
  description = "Fabric workspace ID when created."
}

output "fabric_workspace_name" {
  value       = module.fabric.fabric_workspace_name
  description = "Fabric workspace display name when created."
}

output "fabric_lakehouse_id" {
  value       = module.fabric.fabric_lakehouse_id
  description = "Fabric lakehouse ID when created."
}

output "fabric_lakehouse_name" {
  value       = module.fabric.fabric_lakehouse_name
  description = "Fabric lakehouse display name when created."
}
