output "user_assigned_identity_id" {
  value       = azapi_resource.user_assigned_identity.id
  description = "User-assigned managed identity resource ID."
}

output "user_assigned_identity_principal_id" {
  value       = azapi_resource.user_assigned_identity.output.properties.principalId
  description = "User-assigned managed identity principal ID."
}
