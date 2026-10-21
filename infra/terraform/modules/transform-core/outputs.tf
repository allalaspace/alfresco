output "service_name" {
  description = "Name of the Transform Core Service."
  value       = kubernetes_service.this.metadata[0].name
}
