output "fabric_capacity_id" {
  value       = var.create_capacity ? azapi_resource.fabric_capacity[0].id : null
  description = "Fabric capacity resource ID when created."
}

output "fabric_capacity_name" {
  value       = var.create_capacity ? azapi_resource.fabric_capacity[0].name : null
  description = "Fabric capacity name when created."
}
