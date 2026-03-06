variable "location" {
  type        = string
  description = "Azure region for resources."
  default     = "southcentralus"
}

variable "project_name" {
  type        = string
  description = "Project name prefix for resources."
  default     = "piisentry"
}

variable "fabric_capacity_sku" {
  type        = string
  description = "Fabric capacity SKU."
  default     = "F4"
}

variable "create_fabric_capacity" {
  type        = bool
  description = "Whether to provision Fabric capacity in this deployment."
  default     = false
}

variable "create_fabric_workspace" {
  type        = bool
  description = "Whether to create a Fabric workspace on the configured capacity."
  default     = false
}

variable "fabric_workspace_display_name" {
  type        = string
  description = "Display name for the Fabric workspace."
  default     = "WS_PII_Sentry"
}

variable "create_fabric_lakehouse" {
  type        = bool
  description = "Whether to create a Fabric lakehouse in the workspace."
  default     = true
}

variable "fabric_lakehouse_display_name" {
  type        = string
  description = "Display name for the Fabric lakehouse."
  default     = "LH_PII_Sentry"
}

variable "create_fabric_workspace_git" {
  type        = bool
  description = "Whether to enable Fabric workspace Git integration (GitHub configured connection)."
  default     = false
}

variable "fabric_workspace_git_repository_owner" {
  type        = string
  description = "GitHub owner/org for Fabric workspace Git integration."
  default     = ""
}

variable "fabric_workspace_git_repository_name" {
  type        = string
  description = "GitHub repository name for Fabric workspace Git integration."
  default     = ""
}

variable "fabric_workspace_git_branch_name" {
  type        = string
  description = "Git branch for Fabric workspace Git integration."
  default     = "main"
}

variable "fabric_workspace_git_directory_name" {
  type        = string
  description = "Directory in the Git repository that contains Fabric artifacts. Must start with '/'."
  default     = "/demo-fabric-artifacts"
}

variable "fabric_workspace_git_connection_id" {
  type        = string
  description = "Fabric GitHub connection ID used when workspace Git integration is enabled."
  default     = ""
}

variable "fabric_workspace_git_initialization_strategy" {
  type        = string
  description = "Workspace Git initialization strategy."
  default     = "PreferWorkspace"
}

variable "fabric_capacity_name_override" {
  type        = string
  description = "Override the auto-generated Fabric capacity name."
  default     = ""
}

variable "fabric_capacity_location" {
  type        = string
  description = "Override the region for Fabric capacity when quota is unavailable in the default region."
  default     = ""
}

variable "fabric_location" {
  type        = string
  description = "Azure region for Fabric capacity. Defaults to the main location."
  default     = ""
}

variable "search_sku" {
  type        = string
  description = "Azure AI Search SKU."
  default     = "basic"
}

variable "foundry_sku" {
  type        = string
  description = "Azure AI Foundry account SKU."
  default     = "S0"
}

variable "create_foundry_project" {
  type        = bool
  description = "Whether to provision a Foundry project under the Foundry account."
  default     = true
}

variable "resource_suffix" {
  type        = string
  description = "Optional suffix used to keep resource names globally unique."
  default     = "dev"
}

variable "admin_object_id" {
  type        = string
  description = "Entra object id used for bootstrap RBAC assignments."
  default     = ""
}

variable "fabric_admin_object_id" {
  type        = string
  description = "Optional Entra object id to assign as Fabric capacity admin. Leave empty to skip administration assignment."
  default     = ""
}

variable "create_fabric_connection" {
  type        = bool
  description = "Whether to create the Foundry Fabric connection resource."
  default     = false
}

variable "fabric_connection_target" {
  type        = string
  description = "Fabric connection target identifier used by the Foundry connection resource."
  default     = ""
}

variable "fabric_workspace_id" {
  type        = string
  description = "Fabric workspace ID used for Microsoft Fabric connection custom keys."
  default     = ""
}

variable "fabric_data_agent_id" {
  type        = string
  description = "Fabric Data Agent artifact ID used for Microsoft Fabric connection custom keys."
  default     = ""
}

variable "create_embedding_deployment" {
  type        = bool
  description = "Whether to deploy an embedding model in the Foundry account."
  default     = true
}

variable "create_chat_deployment" {
  type        = bool
  description = "Whether to deploy a chat model (gpt-4o) in the Foundry account."
  default     = true
}

variable "create_bing_search" {
  type        = bool
  description = "Whether to create a Bing Search grounding resource and Foundry connection."
  default     = false
}

variable "bing_api_key" {
  type        = string
  description = "API key for the Bing Grounding resource."
  sensitive   = true
  default     = ""
}
