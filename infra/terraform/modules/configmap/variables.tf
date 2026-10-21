variable "namespace" {
  description = "Namespace where the ConfigMap is created."
  type        = string
}

variable "name" {
  description = "Name of the ConfigMap."
  type        = string
}

variable "labels" {
  description = "Labels applied to the ConfigMap."
  type        = map(string)
  default     = {}
}

variable "public_host" {
  description = "Host advertised to clients."
  type        = string
}

variable "alfresco_node_port" {
  description = "NodePort exposing the Alfresco repository."
  type        = number
}

variable "share_node_port" {
  description = "NodePort exposing the Share UI."
  type        = number
}

variable "activemq_console_node_port" {
  description = "NodePort exposing the ActiveMQ console."
  type        = number
}

variable "db_name" {
  description = "Name of the Alfresco database."
  type        = string
}
