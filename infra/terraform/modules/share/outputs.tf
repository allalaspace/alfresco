output "service_name" {
  description = "Name of the Share Service."
  value       = kubernetes_service.this.metadata[0].name
}
