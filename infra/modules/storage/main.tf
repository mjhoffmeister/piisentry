locals {
  base_name            = lower(replace(var.project_name, "-", ""))
  storage_account_name = substr("${local.base_name}st${substr(md5(var.resource_suffix), 0, 8)}", 0, 24)
}

resource "azapi_resource" "storage_account" {
  type      = "Microsoft.Storage/storageAccounts@2023-05-01"
  name      = local.storage_account_name
  parent_id = var.resource_group_id
  location  = var.location

  body = {
    kind = "StorageV2"
    sku = {
      name = "Standard_LRS"
    }
    properties = {
      minimumTlsVersion        = "TLS1_2"
      supportsHttpsTrafficOnly = true
      allowBlobPublicAccess    = false
      accessTier               = "Hot"
    }
  }
}

resource "azapi_resource" "regulatory_container" {
  type      = "Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01"
  name      = "regulatory"
  parent_id = "${azapi_resource.storage_account.id}/blobServices/default"

  body = {
    properties = {
      publicAccess = "None"
    }
  }
}
