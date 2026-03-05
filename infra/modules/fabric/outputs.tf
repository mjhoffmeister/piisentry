output "fabric_capacity_id" {
  value       = try(azapi_resource.fabric_capacity[0].id, null)
  description = "Fabric capacity resource ID when created."
}

output "fabric_capacity_name" {
  value       = try(azapi_resource.fabric_capacity[0].name, null)
  description = "Fabric capacity name when created."
}

output "fabric_workspace_id" {
  value       = try(fabric_workspace.workspace[0].id, null)
  description = "Fabric workspace ID when created."
}

output "fabric_workspace_name" {
  value       = try(fabric_workspace.workspace[0].display_name, null)
  description = "Fabric workspace display name when created."
}

output "fabric_lakehouse_id" {
  value       = try(fabric_lakehouse.lakehouse[0].id, null)
  description = "Fabric lakehouse ID when created."
}

output "fabric_lakehouse_name" {
  value       = try(fabric_lakehouse.lakehouse[0].display_name, null)
  description = "Fabric lakehouse display name when created."
}
