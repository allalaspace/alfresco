output "service_name" {
  description = "Name of the Alfresco repository Service."
  value       = kubernetes_service.this.metadata[0].name
}

output "pvc_name" {
  description = "Name of the content store persistent volume claim."
  value       = kubernetes_persistent_volume_claim.this.metadata[0].name
}
