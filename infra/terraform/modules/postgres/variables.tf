variable "namespace" {
  description = "Namespace where PostgreSQL is deployed."
  type        = string
}

variable "labels" {
  description = "Labels applied to the resources."
  type        = map(string)
  default     = {}
}

variable "image" {
  description = "PostgreSQL container image."
  type        = string
}

variable "storage" {
  description = "Size of the persistent volume claim."
  type        = string
}

variable "storage_class" {
  description = "StorageClass for the persistent volume claim. Empty uses the cluster default."
  type        = string
  default     = ""
}

variable "db_name" {
  description = "Name of the initial database."
  type        = string
}

variable "secret_name" {
  description = "Secret holding the database credentials."
  type        = string
}

variable "configmap_name" {
  description = "ConfigMap holding the non-secret settings."
  type        = string
}

variable "rollout_timeout" {
  description = "How long Terraform waits for the Deployment rollout to finish."
  type        = string
  default     = "20m"
}
