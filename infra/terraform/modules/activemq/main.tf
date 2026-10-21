locals {
  labels = merge(var.labels, {
    "app.kubernetes.io/component" = "activemq"
  })
}

resource "kubernetes_service" "this" {
  metadata {
    name      = "activemq"
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    selector = local.labels

    port {
      name        = "openwire"
      port        = 61616
      target_port = "openwire"
    }
  }
}

# The console is exposed on a NodePort by default, mirroring the local stack.
# Set console_service_type to "ClusterIP" to keep it reachable only from
# inside the cluster.
resource "kubernetes_service" "console" {
  metadata {
    name      = "activemq-console"
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    type     = var.console_service_type
    selector = local.labels

    port {
      name        = "console"
      port        = 8161
      target_port = "console"
      node_port   = var.console_service_type == "NodePort" ? var.console_node_port : null
    }
  }
}

resource "kubernetes_deployment" "this" {
  metadata {
    name      = "activemq"
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    replicas = 1

    selector {
      match_labels = local.labels
    }

    template {
      metadata {
        labels = local.labels
      }

      spec {
        automount_service_account_token = false
        enable_service_links            = false

        container {
          name              = "activemq"
          image             = var.image
          image_pull_policy = "IfNotPresent"

          port {
            name           = "openwire"
            container_port = 61616
          }

          port {
            name           = "console"
            container_port = 8161
          }

          env {
            name = "ACTIVEMQ_ADMIN_LOGIN"
            value_from {
              secret_key_ref {
                name = var.secret_name
                key  = "ACTIVEMQ_USER"
              }
            }
          }

          env {
            name = "ACTIVEMQ_ADMIN_PASSWORD"
            value_from {
              secret_key_ref {
                name = var.secret_name
                key  = "ACTIVEMQ_PASSWORD"
              }
            }
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "512Mi"
            }
            limits = {
              memory = "1Gi"
            }
          }

          startup_probe {
            exec {
              command = ["bash", "-c", "echo > /dev/tcp/127.0.0.1/61616"]
            }
            period_seconds    = 10
            timeout_seconds   = 5
            failure_threshold = 18
          }

          readiness_probe {
            exec {
              command = ["bash", "-c", "echo > /dev/tcp/127.0.0.1/61616"]
            }
            period_seconds    = 10
            timeout_seconds   = 5
            failure_threshold = 3
          }

          liveness_probe {
            tcp_socket {
              port = "openwire"
            }
            period_seconds    = 30
            timeout_seconds   = 5
            failure_threshold = 5
          }
        }
      }
    }
  }

  # The default 10 minutes is too short on a cold start: images have to be
  # pulled and the Alfresco boot chain takes several minutes.
  timeouts {
    create = var.rollout_timeout
    update = var.rollout_timeout
  }
}

