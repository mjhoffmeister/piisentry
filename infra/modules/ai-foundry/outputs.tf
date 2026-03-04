output "foundry_account_id" {
  value       = azapi_resource.foundry_account.id
  description = "Foundry account resource ID."
}

output "foundry_account_name" {
  value       = azapi_resource.foundry_account.name
  description = "Foundry account name."
}

output "foundry_project_id" {
  value       = var.create_project ? azapi_resource.foundry_project[0].id : null
  description = "Foundry project resource ID."
}

output "foundry_project_name" {
  value       = var.create_project ? azapi_resource.foundry_project[0].name : null
  description = "Foundry project name."
}

output "foundry_project_principal_id" {
  value       = var.create_project ? azapi_resource.foundry_project[0].output.identity.principalId : null
  description = "Foundry project system-assigned managed identity principal ID."
}

output "foundry_project_endpoint" {
  value       = var.create_project ? "https://${azapi_resource.foundry_account.name}.services.ai.azure.com/api/projects/${azapi_resource.foundry_project[0].name}" : null
  description = "Foundry project endpoint URL for data-plane operations."
}

output "fabric_connection_id" {
  value       = var.create_fabric_connection ? azapi_resource.fabric_connection[0].id : null
  description = "Foundry Fabric connection resource ID when created."
}

output "embedding_deployment_name" {
  value       = var.create_embedding_deployment ? azapi_resource.embedding_deployment[0].name : null
  description = "Embedding model deployment name."
}

output "bing_search_id" {
  value       = var.create_bing_search ? azapi_resource.bing_search[0].id : null
  description = "Bing Search grounding resource ID."
}

output "bing_connection_name" {
  value       = length(azapi_resource.bing_connection) > 0 ? azapi_resource.bing_connection[0].name : null
  description = "Foundry Bing grounding connection name."
}
