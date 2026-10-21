output "service_name" {
  description = "Name of the ActiveMQ Service."
  value       = kubernetes_service.this.metadata[0].name
}

output "console_service_name" {
  description = "Name of the ActiveMQ console Service."
  value       = kubernetes_service.console.metadata[0].name
}
