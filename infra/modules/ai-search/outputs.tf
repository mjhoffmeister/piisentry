output "search_service_id" {
  value       = azapi_resource.search_service.id
  description = "Azure AI Search service resource ID."
}

output "search_service_name" {
  value       = azapi_resource.search_service.name
  description = "Azure AI Search service name."
}

output "search_endpoint" {
  value       = "https://${azapi_resource.search_service.name}.search.windows.net"
  description = "Azure AI Search service endpoint URL."
}

output "search_service_principal_id" {
  value       = azapi_resource.search_service.identity[0].principal_id
  description = "Search service system-assigned managed identity principal ID."
}
