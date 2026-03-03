variable "location" {
  type        = string
  description = "Azure region for resources."
  default     = "eastus2"
}

variable "project_name" {
  type        = string
  description = "Project name prefix for resources."
  default     = "piisentry"
}

variable "fabric_capacity_sku" {
  type        = string
  description = "Fabric capacity SKU."
  default     = "F2"
}

variable "search_sku" {
  type        = string
  description = "Azure AI Search SKU."
  default     = "basic"
}

variable "admin_object_id" {
  type        = string
  description = "Entra object id used for bootstrap RBAC assignments."
  default     = ""
}
