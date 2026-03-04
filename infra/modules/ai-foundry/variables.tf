variable "resource_group_id" {
  type        = string
  description = "Resource group ID where Foundry resources will be created."
}

variable "location" {
  type        = string
  description = "Azure region for Foundry resources."
}

variable "project_name" {
  type        = string
  description = "Project name prefix for resources."
}

variable "resource_suffix" {
  type        = string
  description = "Suffix used to keep resource names unique."
}

variable "foundry_sku" {
  type        = string
  description = "Foundry account SKU name."
}

variable "foundry_user_assigned_identity_id" {
  type        = string
  description = "Optional user-assigned identity resource ID to attach to the Foundry account."
  default     = ""
}

variable "create_project" {
  type        = bool
  description = "Whether to create a Foundry project under the account."
  default     = false
}

variable "create_fabric_connection" {
  type        = bool
  description = "Whether to create the Foundry Fabric connection resource."
  default     = false
}

variable "fabric_connection_target" {
  type        = string
  description = "Fabric connection target identifier used by Foundry connection."
  default     = ""
}

variable "create_embedding_deployment" {
  type        = bool
  description = "Whether to deploy an embedding model in the Foundry account."
  default     = false
}

variable "embedding_deployment_name" {
  type        = string
  description = "Deployment name for the embedding model."
  default     = "text-embedding-ada-002"
}

variable "embedding_model_name" {
  type        = string
  description = "Embedding model name from the model catalog."
  default     = "text-embedding-ada-002"
}

variable "embedding_model_version" {
  type        = string
  description = "Embedding model version."
  default     = "2"
}

variable "embedding_deployment_capacity" {
  type        = number
  description = "Capacity (TPM in thousands) for the embedding deployment."
  default     = 10
}

variable "create_chat_deployment" {
  type        = bool
  description = "Whether to deploy a chat model in the Foundry account."
  default     = false
}

variable "chat_deployment_name" {
  type        = string
  description = "Deployment name for the chat model."
  default     = "gpt-4o"
}

variable "chat_model_name" {
  type        = string
  description = "Chat model name from the model catalog."
  default     = "gpt-4o"
}

variable "chat_model_version" {
  type        = string
  description = "Chat model version."
  default     = "2024-11-20"
}

variable "chat_deployment_sku" {
  type        = string
  description = "SKU name for the chat model deployment."
  default     = "GlobalStandard"
}

variable "chat_deployment_capacity" {
  type        = number
  description = "Capacity (TPM in thousands) for the chat model deployment."
  default     = 10
}

variable "create_bing_search" {
  type        = bool
  description = "Whether to create a Bing Search grounding resource and Foundry connection."
  default     = false
}

variable "bing_search_sku" {
  type        = string
  description = "SKU for the Bing Search grounding resource."
  default     = "G1"
}

variable "bing_api_key" {
  type        = string
  description = "API key for the Bing Grounding resource (used in the Foundry connection)."
  sensitive   = true
  default     = ""
}
