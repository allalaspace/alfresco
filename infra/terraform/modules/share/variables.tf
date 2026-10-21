variable "namespace" {
  description = "Namespace where Share is deployed."
  type        = string
}

variable "labels" {
  description = "Labels applied to the resources."
  type        = map(string)
  default     = {}
}

variable "image" {
  description = "Alfresco Share container image."
  type        = string
}

variable "busybox_image" {
  description = "busybox image used by the init containers."
  type        = string
}

variable "service_type" {
  description = "Service type exposing the Share UI. NodePort reproduces the local stack; ClusterIP keeps it cluster-internal."
  type        = string
  default     = "NodePort"
}

variable "node_port" {
  description = "NodePort exposing the Share UI. Ignored when service_type is ClusterIP."
  type        = number
  default     = 30081
}

variable "configmap_name" {
  description = "ConfigMap holding the non-secret settings."
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
