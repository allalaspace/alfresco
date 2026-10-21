output "name" {
  description = "Name of the ConfigMap."
  value       = kubernetes_config_map.this.metadata[0].name
}
