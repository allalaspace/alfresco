locals {
  labels = merge(var.labels, {
    "app.kubernetes.io/component" = "transform-core"
  })
}

resource "kubernetes_service" "this" {
  metadata {
    name      = "transform-core-aio"
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    selector = local.labels

    port {
      name        = "http"
      port        = 8090
      target_port = "http"
    }
  }
}

resource "kubernetes_deployment" "this" {
  metadata {
    name      = "transform-core-aio"
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

        init_container {
          name              = "wait-activemq"
          image             = var.busybox_image
          image_pull_policy = "IfNotPresent"

          command = [
            "sh",
            "-c",
            "until nc -z ${var.activemq_service} 61616; do echo \"attente d'activemq\"; sleep 2; done",
          ]
        }

        container {
          name              = "transform-core-aio"
          image             = var.image
          image_pull_policy = "IfNotPresent"

          port {
            name           = "http"
            container_port = 8090
          }

          env {
            name  = "JAVA_OPTS"
            value = "-XX:MinRAMPercentage=50 -XX:MaxRAMPercentage=80"
          }

          resources {
            requests = {
              cpu    = "200m"
              memory = "512Mi"
            }
            limits = {
              memory = "1536Mi"
            }
          }

          startup_probe {
            http_get {
              path = "/ready"
              port = "http"
            }
            period_seconds    = 10
            timeout_seconds   = 5
            failure_threshold = 18
          }

          readiness_probe {
            http_get {
              path = "/ready"
              port = "http"
            }
            period_seconds    = 20
            timeout_seconds   = 5
            failure_threshold = 3
          }

          liveness_probe {
            tcp_socket {
              port = "http"
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

