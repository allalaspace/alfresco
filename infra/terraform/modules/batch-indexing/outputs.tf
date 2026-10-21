output "deployment_name" {
  description = "Name of the batch-indexing Deployment."
  value       = kubernetes_deployment.this.metadata[0].name
}
