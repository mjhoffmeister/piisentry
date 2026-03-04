variable "resource_group_id" {
  type        = string
  description = "Resource group ID where Fabric resources will be created."
}

variable "location" {
  type        = string
  description = "Azure region for Fabric capacity."
}

variable "project_name" {
  type        = string
  description = "Project name prefix for resources."
}

variable "resource_suffix" {
  type        = string
  description = "Suffix used to keep resource names unique."
}

variable "fabric_capacity_sku" {
  type        = string
  description = "Fabric capacity SKU."
}

variable "admin_object_id" {
  type        = string
  description = "Entra object ID to set as Fabric capacity admin."
  default     = ""
}

variable "create_capacity" {
  type        = bool
  description = "Whether to create the Fabric capacity resource."
  default     = true
}
