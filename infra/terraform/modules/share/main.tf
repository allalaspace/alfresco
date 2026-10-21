locals {
  labels = merge(var.labels, {
    "app.kubernetes.io/component" = "share"
  })
}

resource "kubernetes_service" "this" {
  metadata {
    name      = "share"
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    type     = var.service_type
    selector = local.labels

    port {
      name        = "http"
      port        = 8080
      target_port = "http"
      node_port   = var.service_type == "NodePort" ? var.node_port : null
    }
  }
}

resource "kubernetes_deployment" "this" {
  metadata {
    name      = "share"
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    replicas = 1

    # Share stays in init until Alfresco is ready, which exceeds the 600s
    # Kubernetes default on a cold start.
    progress_deadline_seconds = 1800

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
          name              = "wait-alfresco"
          image             = var.busybox_image
          image_pull_policy = "IfNotPresent"

          command = [
            "sh",
            "-c",
            "until wget -q -O- http://${var.alfresco_service}:8080/alfresco/api/-default-/public/alfresco/versions/1/probes/-ready-; do echo \"attente d'alfresco\"; sleep 5; done",
          ]
        }

        container {
          name              = "share"
          image             = var.image
          image_pull_policy = "IfNotPresent"

          port {
            name           = "http"
            container_port = 8080
          }

          env {
            name = "ALFRESCO_PUBLIC_HOST"
            value_from {
              config_map_key_ref {
                name = var.configmap_name
                key  = "ALFRESCO_PUBLIC_HOST"
              }
            }
          }

          env {
            name = "ALFRESCO_PORT"
            value_from {
              config_map_key_ref {
                name = var.configmap_name
                key  = "ALFRESCO_PORT"
              }
            }
          }

          env {
            name = "SHARE_PORT"
            value_from {
              config_map_key_ref {
                name = var.configmap_name
                key  = "SHARE_PORT"
              }
            }
          }

          env {
            name  = "REPO_HOST"
            value = var.alfresco_service
          }

          env {
            name  = "REPO_PORT"
            value = "8080"
          }

          env {
            name  = "CSRF_FILTER_ORIGIN"
            value = "http://$(ALFRESCO_PUBLIC_HOST):$(SHARE_PORT)"
          }

          env {
            name  = "CSRF_FILTER_REFERER"
            value = "http://$(ALFRESCO_PUBLIC_HOST):$(SHARE_PORT)/share/.*"
          }

          env {
            name  = "JAVA_OPTS"
            value = "-XX:MinRAMPercentage=50 -XX:MaxRAMPercentage=80 -Dalfresco.host=$(ALFRESCO_PUBLIC_HOST) -Dalfresco.port=$(ALFRESCO_PORT) -Dalfresco.context=alfresco -Dalfresco.protocol=http"
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
            http_get {
              path = "/share"
              port = "http"
            }
            period_seconds    = 10
            timeout_seconds   = 5
            failure_threshold = 18
          }

          readiness_probe {
            http_get {
              path = "/share"
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

