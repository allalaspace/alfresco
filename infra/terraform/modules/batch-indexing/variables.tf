variable "namespace" {
  description = "Namespace where batch-indexing is deployed."
  type        = string
}

variable "labels" {
  description = "Labels applied to the resources."
  type        = map(string)
  default     = {}
}

variable "image" {
  description = "Elasticsearch batch-indexing container image."
  type        = string
}

variable "busybox_image" {
  description = "busybox image used by the init containers."
  type        = string
}

variable "secret_name" {
  description = "Secret holding the credentials."
  type        = string
}

variable "configmap_name" {
  description = "ConfigMap holding the non-secret settings."
  type        = string
}

variable "postgres_service" {
  description = "Name of the PostgreSQL Service."
  type        = string
}

variable "elasticsearch_service" {
  description = "Name of the Elasticsearch Service."
  type        = string
}

variable "activemq_service" {
  description = "Name of the ActiveMQ Service."
  type        = string
}

variable "transform_core_service" {
  description = "Name of the Transform Core Service."
  type        = string
}

variable "alfresco_service" {
  description = "Name of the Alfresco repository Service."
  type        = string
}

variable "rollout_timeout" {
  description = "How long Terraform waits for the Deployment rollout to finish."
  type        = string
  default     = "20m"
}
