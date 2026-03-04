locals {
  base_name     = lower(replace(var.project_name, "-", ""))
  capacity_name = substr("${local.base_name}fabric${var.resource_suffix}", 0, 63)
}

resource "azapi_resource" "fabric_capacity" {
  count = var.create_capacity ? 1 : 0

  type      = "Microsoft.Fabric/capacities@2023-11-01"
  name      = local.capacity_name
  parent_id = var.resource_group_id
  location  = var.location

  body = {
    sku = {
      name = var.fabric_capacity_sku
      tier = "Fabric"
    }
    properties = {
      administration = var.admin_object_id != "" ? {
        members = [var.admin_object_id]
      } : null
    }
  }
}
