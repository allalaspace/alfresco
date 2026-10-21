output "service_name" {
  description = "Name of the Elasticsearch Service."
  value       = kubernetes_service.this.metadata[0].name
}

output "pvc_name" {
  description = "Name of the Elasticsearch persistent volume claim."
  value       = kubernetes_persistent_volume_claim.this.metadata[0].name
}
