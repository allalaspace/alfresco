variable "namespace" {
  description = "Namespace where the Secret is created."
  type        = string
}

variable "name" {
  description = "Name of the Secret."
  type        = string
}

variable "labels" {
  description = "Labels applied to the Secret."
  type        = map(string)
  default     = {}
}

variable "db_user" {
  description = "Database user."
  type        = string
}

variable "db_password" {
  description = "Database password."
  type        = string
  sensitive   = true
}

variable "activemq_user" {
  description = "ActiveMQ admin login."
  type        = string
}

variable "activemq_password" {
  description = "ActiveMQ admin password."
  type        = string
  sensitive   = true
}

variable "transform_shared_secret" {
  description = "Secret shared between ACS and batch-indexing."
  type        = string
  sensitive   = true
}

variable "alfresco_admin_user" {
  description = "Alfresco bootstrap account user."
  type        = string
}

variable "alfresco_admin_password" {
  description = "Alfresco bootstrap account password."
  type        = string
  sensitive   = true
}

variable "metadata_keystore_password" {
  description = "Password of the metadata keystore shipped in the Alfresco image."
  type        = string
  sensitive   = true
}

variable "metadata_keystore_metadata_password" {
  description = "Password of the metadata alias inside the keystore shipped in the Alfresco image."
  type        = string
  sensitive   = true
}
