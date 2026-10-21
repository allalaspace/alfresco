variable "namespace" {
  description = "Namespace where the Alfresco stack is deployed."
  type        = string
  default     = "alfresco"
}

variable "labels" {
  description = "Labels added to every resource."
  type        = map(string)
  default     = {}
}

# --- Cluster connection -----------------------------------------------------

variable "kubeconfig_path" {
  description = "Path to the kubeconfig used by the Kubernetes provider. Defaults to the kubeconfig of the current user."
  type        = string
  default     = null
}

variable "kube_context" {
  description = "Context of the kubeconfig to use. Defaults to the current context, like kubectl."
  type        = string
  default     = null
}

# --- Image versions ---------------------------------------------------------

variable "acs_version" {
  description = "Tag of the Alfresco Content Repository Community image."
  type        = string
  default     = "26.2.0"
}

variable "share_version" {
  description = "Tag of the Alfresco Share image."
  type        = string
  default     = "26.2.2"
}

variable "transform_version" {
  description = "Tag of the Transform Core AIO image."
  type        = string
  default     = "5.4.4"
}

variable "postgres_version" {
  description = "Tag of the PostgreSQL image."
  type        = string
  default     = "17.9"
}

variable "elasticsearch_version" {
  description = "Tag of the Elasticsearch image."
  type        = string
  default     = "8.17.10"
}

variable "batch_indexing_version" {
  description = "Tag of the Elasticsearch batch-indexing image."
  type        = string
  default     = "5.8.0"
}

variable "activemq_version" {
  description = "Tag of the ActiveMQ image."
  type        = string
  default     = "6.2.9-jre17-rockylinux8"
}

variable "busybox_version" {
  description = "Tag of the busybox image used by the init containers."
  type        = string
  default     = "1.36"
}

# --- Public exposure --------------------------------------------------------

variable "public_host" {
  description = "Host advertised to clients for the Alfresco and Share endpoints."
  type        = string
  default     = "localhost"
}

variable "alfresco_node_port" {
  description = "NodePort exposing the Alfresco repository."
  type        = number
  default     = 30080
}

variable "share_node_port" {
  description = "NodePort exposing the Alfresco Share UI."
  type        = number
  default     = 30081
}

variable "activemq_console_node_port" {
  description = "NodePort exposing the ActiveMQ console."
  type        = number
  default     = 30161
}

# --- Database ---------------------------------------------------------------

variable "db_name" {
  description = "Name of the Alfresco database."
  type        = string
  default     = "alfresco"
}

variable "db_user" {
  description = "Database user used by Alfresco and batch-indexing."
  type        = string
  default     = "alfresco"
}

variable "db_password" {
  description = "Database password. Sourced from infra/alfresco/.env — do not commit."
  type        = string
  sensitive   = true
}

# --- Messaging --------------------------------------------------------------

variable "activemq_user" {
  description = "ActiveMQ admin login."
  type        = string
  default     = "admin"
}

variable "activemq_password" {
  description = "ActiveMQ admin password. Sourced from infra/alfresco/.env — do not commit."
  type        = string
  sensitive   = true
}

# --- Shared secret ----------------------------------------------------------

variable "transform_shared_secret" {
  description = "Secret shared between ACS and batch-indexing. Sourced from infra/alfresco/.env — do not commit."
  type        = string
  sensitive   = true
}

# --- Bootstrap account ------------------------------------------------------

variable "alfresco_admin_user" {
  description = "Alfresco bootstrap account user."
  type        = string
  default     = "admin"
}

variable "alfresco_admin_password" {
  description = "Alfresco bootstrap account password. Sourced from infra/alfresco/.env — do not commit."
  type        = string
  sensitive   = true
}

# --- Storage ----------------------------------------------------------------

variable "postgres_storage" {
  description = "Size of the PostgreSQL persistent volume claim."
  type        = string
  default     = "8Gi"
}

variable "elasticsearch_storage" {
  description = "Size of the Elasticsearch persistent volume claim."
  type        = string
  default     = "5Gi"
}

variable "elasticsearch_security_enabled" {
  description = "Whether Elasticsearch xpack security is enabled. Off by default, like the kustomize stack, where ACS and batch-indexing connect without credentials."
  type        = bool
  default     = false
}

variable "alfresco_storage" {
  description = "Size of the Alfresco content store persistent volume claim."
  type        = string
  default     = "10Gi"
}

variable "storage_class" {
  description = "StorageClass used by the persistent volume claims. Empty means the cluster default."
  type        = string
  default     = ""
}
