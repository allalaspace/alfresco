locals {
  # Labels applied to every resource, on top of the per-component ones.
  common_labels = merge(var.labels, {
    "app.kubernetes.io/name"    = "alfresco"
    "app.kubernetes.io/part-of" = "alfresco"
  })

  # The Alfresco content repository reads its keystore passwords from the
  # image itself. They are already declared in infra/kubernetes/alfresco.yaml
  # and must stay aligned with the keystore shipped in the container, so the
  # values are read from that manifest rather than duplicated here.
  #
  # The two passwords are not written into the Deployment spec: they go into
  # the Kubernetes Secret and the container resolves them through
  # $(METADATA_KEYSTORE_PASSWORD) style references, so they are never
  # readable from the Deployment definition.
  alfresco_manifest = file("${path.module}/../kubernetes/alfresco.yaml")

  keystore_properties = [
    "encryption.keystore.type",
    "encryption.cipherAlgorithm",
    "encryption.keyAlgorithm",
    "encryption.keystore.location",
    "metadata-keystore.aliases",
    "metadata-keystore.metadata.algorithm",
  ]

  keystore = {
    for key in local.keystore_properties :
    key => try(regexall("-D${key}=([^\\s]+)", local.alfresco_manifest)[0][0], null)
  }

  # Passwords are read from the manifest and handed to the Secret module.
  metadata_keystore_password          = try(regexall("-Dmetadata-keystore.password=([^\\s]+)", local.alfresco_manifest)[0][0], null)
  metadata_keystore_metadata_password = try(regexall("-Dmetadata-keystore.metadata.password=([^\\s]+)", local.alfresco_manifest)[0][0], null)
}

module "namespace" {
  source = "./modules/namespace"

  name   = var.namespace
  labels = local.common_labels
}

module "configmap" {
  source = "./modules/configmap"

  namespace                  = var.namespace
  name                       = "alfresco-config"
  labels                     = local.common_labels
  public_host                = var.public_host
  alfresco_node_port         = var.alfresco_node_port
  share_node_port            = var.share_node_port
  activemq_console_node_port = var.activemq_console_node_port
  db_name                    = var.db_name
}

module "secret" {
  source = "./modules/secret"

  namespace               = var.namespace
  name                    = "alfresco-secret"
  labels                  = local.common_labels
  db_user                 = var.db_user
  db_password             = var.db_password
  activemq_user           = var.activemq_user
  activemq_password       = var.activemq_password
  transform_shared_secret = var.transform_shared_secret
  alfresco_admin_user     = var.alfresco_admin_user
  alfresco_admin_password = var.alfresco_admin_password

  metadata_keystore_password          = local.metadata_keystore_password
  metadata_keystore_metadata_password = local.metadata_keystore_metadata_password
}

module "postgres" {
  source = "./modules/postgres"

  namespace      = var.namespace
  labels         = local.common_labels
  image          = "postgres:${var.postgres_version}"
  storage        = var.postgres_storage
  storage_class  = var.storage_class
  db_name        = var.db_name
  secret_name    = module.secret.name
  configmap_name = module.configmap.name
}

module "elasticsearch" {
  source = "./modules/elasticsearch"

  namespace     = var.namespace
  labels        = local.common_labels
  image         = "docker.elastic.co/elasticsearch/elasticsearch:${var.elasticsearch_version}"
  storage       = var.elasticsearch_storage
  storage_class = var.storage_class

  security_enabled = var.elasticsearch_security_enabled
}

module "activemq" {
  source = "./modules/activemq"

  namespace         = var.namespace
  labels            = local.common_labels
  image             = "docker.io/alfresco/alfresco-activemq:${var.activemq_version}"
  console_node_port = var.activemq_console_node_port
  secret_name       = module.secret.name
}

module "transform_core" {
  source = "./modules/transform-core"

  namespace        = var.namespace
  labels           = local.common_labels
  image            = "docker.io/alfresco/alfresco-transform-core-aio:${var.transform_version}"
  busybox_image    = "busybox:${var.busybox_version}"
  activemq_service = module.activemq.service_name
}

module "alfresco" {
  source = "./modules/alfresco"

  namespace              = var.namespace
  labels                 = local.common_labels
  image                  = "docker.io/alfresco/alfresco-content-repository-community:${var.acs_version}"
  busybox_image          = "busybox:${var.busybox_version}"
  storage                = var.alfresco_storage
  storage_class          = var.storage_class
  node_port              = var.alfresco_node_port
  secret_name            = module.secret.name
  configmap_name         = module.configmap.name
  postgres_service       = module.postgres.service_name
  elasticsearch_service  = module.elasticsearch.service_name
  activemq_service       = module.activemq.service_name
  transform_core_service = module.transform_core.service_name
  keystore_properties    = local.keystore
}

module "share" {
  source = "./modules/share"

  namespace        = var.namespace
  labels           = local.common_labels
  image            = "docker.io/alfresco/alfresco-share:${var.share_version}"
  busybox_image    = "busybox:${var.busybox_version}"
  node_port        = var.share_node_port
  configmap_name   = module.configmap.name
  alfresco_service = module.alfresco.service_name
}

module "batch_indexing" {
  source = "./modules/batch-indexing"

  namespace              = var.namespace
  labels                 = local.common_labels
  image                  = "docker.io/alfresco/alfresco-elasticsearch-batch-indexing:${var.batch_indexing_version}"
  busybox_image          = "busybox:${var.busybox_version}"
  secret_name            = module.secret.name
  configmap_name         = module.configmap.name
  postgres_service       = module.postgres.service_name
  elasticsearch_service  = module.elasticsearch.service_name
  activemq_service       = module.activemq.service_name
  transform_core_service = module.transform_core.service_name
  alfresco_service       = module.alfresco.service_name
}
