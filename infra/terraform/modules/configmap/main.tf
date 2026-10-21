resource "kubernetes_config_map" "this" {
  metadata {
    name      = var.name
    namespace = var.namespace
    labels    = var.labels
  }

  data = {
    ALFRESCO_PUBLIC_HOST  = var.public_host
    ALFRESCO_PORT         = tostring(var.alfresco_node_port)
    SHARE_PORT            = tostring(var.share_node_port)
    ACTIVEMQ_CONSOLE_PORT = tostring(var.activemq_console_node_port)
    DB_NAME               = var.db_name
  }
}
