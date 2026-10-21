variable "namespace" {
  description = "Namespace where ActiveMQ is deployed."
  type        = string
}

variable "labels" {
  description = "Labels applied to the resources."
  type        = map(string)
  default     = {}
}

variable "image" {
  description = "ActiveMQ container image."
  type        = string
}

variable "console_service_type" {
  description = "Service type exposing the ActiveMQ console. NodePort reproduces the local stack; ClusterIP keeps it cluster-internal."
  type        = string
  default     = "NodePort"
}

variable "console_node_port" {
  description = "NodePort exposing the ActiveMQ console. Ignored when console_service_type is ClusterIP."
  type        = number
  default     = 30161
}

variable "secret_name" {
  description = "Secret holding the ActiveMQ credentials."
  type        = string
}

variable "rollout_timeout" {
  description = "How long Terraform waits for the Deployment rollout to finish."
  type        = string
  default     = "20m"
}
