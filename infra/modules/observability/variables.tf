variable "resource_group_id" {
  type        = string
  description = "Resource group ID where observability resources will be created."
}

variable "location" {
  type        = string
  description = "Azure region for observability resources."
}

variable "project_name" {
  type        = string
  description = "Project name prefix for resources."
}

variable "resource_suffix" {
  type        = string
  description = "Suffix used to keep resource names unique."
}
