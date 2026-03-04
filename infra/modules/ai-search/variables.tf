variable "resource_group_id" {
  type        = string
  description = "Resource group ID where Azure AI Search will be created."
}

variable "location" {
  type        = string
  description = "Azure region for the search service."
}

variable "project_name" {
  type        = string
  description = "Project name prefix for resources."
}

variable "resource_suffix" {
  type        = string
  description = "Suffix used to keep resource names unique."
}

variable "search_sku" {
  type        = string
  description = "Azure AI Search SKU name."
}
