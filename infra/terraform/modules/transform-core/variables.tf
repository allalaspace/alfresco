variable "namespace" {
  description = "Namespace where Transform Core is deployed."
  type        = string
}

variable "labels" {
  description = "Labels applied to the resources."
  type        = map(string)
  default     = {}
}

variable "image" {
  description = "Transform Core AIO container image."
  type        = string
}

variable "busybox_image" {
  description = "busybox image used by the init containers."
  type        = string
}

variable "activemq_service" {
  description = "Name of the ActiveMQ Service the init container waits for."
  type        = string
}

variable "rollout_timeout" {
  description = "How long Terraform waits for the Deployment rollout to finish."
  type        = string
  default     = "20m"
}
