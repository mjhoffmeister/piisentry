variable "resource_group_id" {
  type        = string
  description = "Resource group ID where identity resources will be created."
}

variable "location" {
  type        = string
  description = "Azure region for identity resources."
}

variable "project_name" {
  type        = string
  description = "Project name prefix for resources."
}

variable "resource_suffix" {
  type        = string
  description = "Suffix used to keep resource names unique."
}

variable "admin_object_id" {
  type        = string
  description = "Entra object ID for bootstrap role assignments."
  default     = ""
}

variable "foundry_project_id" {
  type        = string
  description = "Foundry project resource ID used for RBAC assignments."
  default     = ""
}

variable "search_service_id" {
  type        = string
  description = "Azure AI Search service resource ID used for RBAC assignments."
}

variable "contributor_role_definition_id" {
  type        = string
  description = "Built-in Contributor role definition GUID."
  default     = "b24988ac-6180-42a0-ab88-20f7382dd24c"
}

variable "search_contributor_role_definition_id" {
  type        = string
  description = "Built-in Search Service Contributor role definition GUID."
  default     = "7ca78c08-252a-4471-8644-bb5ff32d4ba0"
}

variable "ai_developer_role_definition_id" {
  type        = string
  description = "Built-in Azure AI Developer role definition GUID."
  default     = "64702f94-c441-49e6-a78b-ef80e0188fee"
}

variable "storage_account_id" {
  type        = string
  description = "Storage account resource ID used for RBAC assignments."
}

variable "storage_blob_data_contributor_role_definition_id" {
  type        = string
  description = "Built-in Storage Blob Data Contributor role definition GUID."
  default     = "ba92f5b4-2d11-453d-a403-e96b0029c9fe"
}

variable "search_service_principal_id" {
  type        = string
  description = "Search service system-assigned managed identity principal ID for RBAC assignments."
  default     = ""
}

variable "storage_blob_data_reader_role_definition_id" {
  type        = string
  description = "Built-in Storage Blob Data Reader role definition GUID."
  default     = "2a2b9908-6ea1-4ae2-8e65-a410df84e7d1"
}

variable "foundry_account_id" {
  type        = string
  description = "Foundry account resource ID for RBAC assignments."
  default     = ""
}

variable "azure_ai_user_role_definition_id" {
  type        = string
  description = "Built-in Azure AI User role definition GUID."
  default     = "53ca6127-db72-4b80-b1b0-d745d6d5456d"
}

variable "foundry_project_principal_id" {
  type        = string
  description = "Foundry project system-assigned managed identity principal ID."
  default     = ""
}

variable "search_index_data_reader_role_definition_id" {
  type        = string
  description = "Built-in Search Index Data Reader role definition GUID."
  default     = "1407120a-92aa-4202-b7e9-c0e197c71c8f"
}

variable "search_index_data_contributor_role_definition_id" {
  type        = string
  description = "Built-in Search Index Data Contributor role definition GUID."
  default     = "8ebe5a00-799e-43f5-93ac-243d3dce84a7"
}

variable "cognitive_services_user_role_definition_id" {
  type        = string
  description = "Built-in Cognitive Services User role definition GUID."
  default     = "a97b65f3-24c7-4388-baec-2e87135dc908"
}

variable "cognitive_services_openai_user_role_definition_id" {
  type        = string
  description = "Built-in Cognitive Services OpenAI User role definition GUID."
  default     = "5e0bd9bd-7b93-4f28-af87-19fc36ad61bd"
}
