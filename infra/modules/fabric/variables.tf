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

variable "capacity_name_override" {
  type        = string
  description = "Override the auto-generated capacity name. Leave empty to use the default."
  default     = ""
}

variable "capacity_location" {
  type        = string
  description = "Override the region for Fabric capacity. Leave empty to use the default location."
  default     = ""
}

variable "create_capacity" {
  type        = bool
  description = "Whether to create the Fabric capacity resource."
  default     = true
}

variable "create_workspace" {
  type        = bool
  description = "Whether to create a Fabric workspace."
  default     = false
}

variable "workspace_display_name" {
  type        = string
  description = "Display name for the Fabric workspace."
  default     = "WS_PII_Sentry"
}

variable "create_lakehouse" {
  type        = bool
  description = "Whether to create a Fabric lakehouse."
  default     = true
}

variable "lakehouse_display_name" {
  type        = string
  description = "Display name for the Fabric lakehouse."
  default     = "LH_PII_Sentry"
}

variable "create_workspace_git" {
  type        = bool
  description = "Whether to configure Git integration for the Fabric workspace."
  default     = false
}

variable "workspace_git_repository_owner" {
  type        = string
  description = "GitHub owner/org for workspace Git integration."
  default     = ""
}

variable "workspace_git_repository_name" {
  type        = string
  description = "GitHub repository name for workspace Git integration."
  default     = ""
}

variable "workspace_git_branch_name" {
  type        = string
  description = "Git branch for workspace Git integration."
  default     = "main"
}

variable "workspace_git_directory_name" {
  type        = string
  description = "Directory in repo for Fabric item sync. Must start with '/'."
  default     = "/demo-fabric-artifacts"
}

variable "workspace_git_connection_id" {
  type        = string
  description = "Fabric configured connection ID for GitHub integration."
  default     = ""
}

variable "workspace_git_initialization_strategy" {
  type        = string
  description = "Initialization strategy for workspace Git integration."
  default     = "PreferWorkspace"
}
