variable "workspace_id" {
  type = string
}

variable "tre_id" {
  type = string
}

variable "tre_resource_id" {
  type = string
}

variable "sql_sku" {
  type = string
}

variable "db_name" {
  type = string
}

variable "storage_gb" {
  type = number

  validation {
    condition     = var.storage_gb > 1 && var.storage_gb < 1024
    error_message = "The storage value is out of range."
  }
}

variable "arm_environment" {
  type = string
}

variable "arm_client_id" {
  type        = string
  description = "The Service Princiapl ID for managing Azure resources"
}

variable "arm_subscription_id" {
  type        = string
  description = "The Subscription ID of the TRE"
}