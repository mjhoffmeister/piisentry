output "storage_account_id" {
  value       = azapi_resource.storage_account.id
  description = "Storage account resource ID."
}

output "storage_account_name" {
  value       = azapi_resource.storage_account.name
  description = "Storage account name."
}

output "regulatory_container_id" {
  value       = azapi_resource.regulatory_container.id
  description = "Regulatory documents container resource ID."
}
