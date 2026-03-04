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
  default     = "F2"
}

variable "create_fabric_capacity" {
  type        = bool
  description = "Whether to provision Fabric capacity in this deployment."
  default     = false
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
