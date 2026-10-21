variable "namespace" {
  description = "Namespace where Elasticsearch is deployed."
  type        = string
}

variable "labels" {
  description = "Labels applied to the resources."
  type        = map(string)
  default     = {}
}

variable "image" {
  description = "Elasticsearch container image."
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

variable "security_enabled" {
  description = "Whether Elasticsearch xpack security is enabled. Disabled by default to match the local stack, where ACS and batch-indexing connect without credentials."
  type        = bool
  default     = false
}

variable "rollout_timeout" {
  description = "How long Terraform waits for the Deployment rollout to finish."
  type        = string
  default     = "20m"
}
