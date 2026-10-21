output "namespace" {
  description = "Namespace hosting the Alfresco stack."
  value       = module.namespace.name
}

output "endpoints" {
  description = "Endpoints exposed by the stack."
  value = {
    alfresco_api     = "http://${var.public_host}:${var.alfresco_node_port}/alfresco/api/-default-/public/alfresco/versions/1"
    alfresco_ready   = "http://${var.public_host}:${var.alfresco_node_port}/alfresco/api/-default-/public/alfresco/versions/1/probes/-ready-"
    share            = "http://${var.public_host}:${var.share_node_port}/share"
    activemq_console = "http://${var.public_host}:${var.activemq_console_node_port}"
  }
}

output "internal_services" {
  description = "Cluster-internal service names and ports."
  value = {
    postgres       = "${module.postgres.service_name}:5432"
    elasticsearch  = "${module.elasticsearch.service_name}:9200"
    activemq       = "${module.activemq.service_name}:61616"
    transform_core = "${module.transform_core.service_name}:8090"
    alfresco       = "${module.alfresco.service_name}:8080"
    share          = "${module.share.service_name}:8080"
  }
}

output "storage_claims" {
  description = "Persistent volume claims created by the stack."
  value = {
    postgres      = module.postgres.pvc_name
    elasticsearch = module.elasticsearch.pvc_name
    alfresco      = module.alfresco.pvc_name
  }
}

output "secret_name" {
  description = "Name of the Kubernetes Secret holding the credentials."
  value       = module.secret.name
}
