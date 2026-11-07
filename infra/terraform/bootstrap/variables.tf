variable "project_name" {
  description = "Prefix for project resource names"
  type        = string
  default     = "nyc-taxi"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "koreacentral"
}

variable "state_storage_account_name" {
  description = "Globally unique storage account name for Terraform state"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.state_storage_account_name))
    error_message = "Use 3 to 24 lowercase letters or digits."
  }
}