terraform {
  required_version = ">= 1.8.0"

  required_providers {
    azapi = {
      source  = "azure/azapi"
      version = "~> 2.8.0"
    }
  }
}

provider "azapi" {}

locals {
  phase = "phase0"
}
