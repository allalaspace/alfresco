variable "namespace" {
  description = "Namespace where the Alfresco repository is deployed."
  type        = string
}

variable "labels" {
  description = "Labels applied to the resources."
  type        = map(string)
  default     = {}
}

variable "image" {
  description = "Alfresco Content Repository Community container image."
  type        = string
}

variable "busybox_image" {
  description = "busybox image used by the init containers."
  type        = string
}

variable "storage" {
  description = "Size of the content store persistent volume claim."
  type        = string
}

variable "storage_class" {
  description = "StorageClass for the persistent volume claim. Empty uses the cluster default."
  type        = string
  default     = ""
}

variable "service_type" {
  description = "Service type exposing the Alfresco repository. NodePort reproduces the local stack; ClusterIP keeps it cluster-internal."
  type        = string
  default     = "NodePort"
}

variable "node_port" {
  description = "NodePort exposing the Alfresco repository. Ignored when service_type is ClusterIP."
  type        = number
  default     = 30080
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

variable "keystore_properties" {
  description = "Keystore settings read from the existing alfresco.yaml manifest, keyed by the -D property name."
  type        = map(string)
}

variable "rollout_timeout" {
  description = "How long Terraform waits for the Deployment rollout to finish."
  type        = string
  default     = "20m"
}
