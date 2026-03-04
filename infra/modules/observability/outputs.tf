output "log_analytics_workspace_id" {
  value       = azapi_resource.log_analytics_workspace.id
  description = "Log Analytics workspace resource ID."
}

output "application_insights_id" {
  value       = azapi_resource.application_insights.id
  description = "Application Insights resource ID."
}

output "app_insights_connection_string" {
  value       = azapi_resource.application_insights.output.properties.ConnectionString
  description = "Application Insights connection string."
  sensitive   = true
}
