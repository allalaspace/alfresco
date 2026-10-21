output "name" {
  description = "Name of the Secret."
  value       = kubernetes_secret.this.metadata[0].name
}
