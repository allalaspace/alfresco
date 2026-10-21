locals {
  labels = merge(var.labels, {
    "app.kubernetes.io/component" = "batch-indexing"
  })
}

resource "kubernetes_deployment" "this" {
  metadata {
    name      = "batch-indexing"
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    replicas = 1

    # Indexing stays in init until Alfresco is ready, which exceeds the 600s
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
          name              = "wait-dependencies"
          image             = var.busybox_image
          image_pull_policy = "IfNotPresent"

          command = [
            "sh",
            "-c",
            # Joined with a newline, not a space: "done until" is a syntax
            # error for sh, "done\nuntil" is not.
            join("\n", [
              "until wget -q -O- http://${var.elasticsearch_service}:9200/_cluster/health | grep -E -q 'green|yellow'; do echo \"attente d'elasticsearch\"; sleep 3; done",
              "until wget -q -O- http://${var.alfresco_service}:8080/alfresco/api/-default-/public/alfresco/versions/1/probes/-ready-; do echo \"attente d'alfresco\"; sleep 5; done",
              "until wget -q -O- http://${var.transform_core_service}:8090/ready; do echo \"attente du transform core\"; sleep 3; done",
            ]),
          ]
        }

        container {
          name              = "batch-indexing"
          image             = var.image
          image_pull_policy = "IfNotPresent"

          env {
            name = "DB_USER"
            value_from {
              secret_key_ref {
                name = var.secret_name
                key  = "DB_USER"
              }
            }
          }

          env {
            name = "DB_PASSWORD"
            value_from {
              secret_key_ref {
                name = var.secret_name
                key  = "DB_PASSWORD"
              }
            }
          }

          env {
            name = "DB_NAME"
            value_from {
              config_map_key_ref {
                name = var.configmap_name
                key  = "DB_NAME"
              }
            }
          }

          env {
            name = "TRANSFORM_SHARED_SECRET"
            value_from {
              secret_key_ref {
                name = var.secret_name
                key  = "TRANSFORM_SHARED_SECRET"
              }
            }
          }

          env {
            name  = "JAVA_OPTS"
            value = "-Xms256m -Xmx768m"
          }

          env {
            name  = "SPRING_DATASOURCE_URL"
            value = "jdbc:postgresql://${var.postgres_service}:5432/$(DB_NAME)"
          }

          env {
            name  = "SPRING_DATASOURCE_USERNAME"
            value = "$(DB_USER)"
          }

          env {
            name  = "SPRING_DATASOURCE_PASSWORD"
            value = "$(DB_PASSWORD)"
          }

          env {
            name  = "SPRING_ELASTICSEARCH_REST_URIS"
            value = "http://${var.elasticsearch_service}:9200"
          }

          env {
            name  = "ALFRESCO_ACCEPTEDCONTENTMEDIATYPESCACHE_BASEURL"
            value = "http://${var.transform_core_service}:8090/transform/config"
          }

          env {
            name  = "ALFRESCO_ACS_URL"
            value = "http://${var.alfresco_service}:8080"
          }

          env {
            name  = "ALFRESCO_CONTENT_TRANSFORM_SHAREDSECRET"
            value = "$(TRANSFORM_SHARED_SECRET)"
          }

          env {
            name  = "ALFRESCO_REINDEX_CONTINUOUS_POLLINGINTERVAL"
            value = "15s"
          }

          env {
            name  = "ALFRESCO_REINDEX_CONTINUOUS_CATCHUPPOLLINGINTERVAL"
            value = "1s"
          }

          env {
            name  = "ALFRESCO_REINDEX_CONTINUOUS_MAXWINDOW"
            value = "30m"
          }

          env {
            name  = "ALFRESCO_REINDEX_CONTINUOUS_OVERLAP"
            value = "10m"
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

