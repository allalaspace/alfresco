locals {
  labels = merge(var.labels, {
    "app.kubernetes.io/component" = "postgres"
  })
}

resource "kubernetes_persistent_volume_claim" "this" {
  metadata {
    name      = "postgres-data"
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    access_modes = ["ReadWriteOnce"]

    resources {
      requests = {
        storage = var.storage
      }
    }

    storage_class_name = var.storage_class != "" ? var.storage_class : null
  }

  # The default StorageClass uses WaitForFirstConsumer: the claim stays
  # Pending until a pod actually mounts it. The provider waits for the claim
  # to reach Bound, which would never happen here because the Deployment
  # that consumes it is created after this resource. Waiting is therefore
  # disabled, and the claim binds once the pod is scheduled.
  wait_until_bound = false
}

resource "kubernetes_service" "this" {
  metadata {
    name      = "postgres"
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    selector = local.labels

    port {
      name        = "postgres"
      port        = 5432
      target_port = "postgres"
    }
  }
}

resource "kubernetes_deployment" "this" {
  metadata {
    name      = "postgres"
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    replicas = 1

    strategy {
      type = "Recreate"
    }

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

        # The official Postgres image must start as root: its entrypoint
        # chmods the data directory to 0700, then drops to the postgres user.
        # Docker Desktop's local-path volumes are root:root mode 0777, and a
        # non-root initdb fails with "Operation not permitted" on that chmod.
        security_context {
          fs_group     = 999
          run_as_user  = 0
          run_as_group = 0
        }

        container {
          name              = "postgres"
          image             = var.image
          image_pull_policy = "IfNotPresent"

          args = [
            "postgres",
            "-c",
            "max_connections=300",
            "-c",
            "log_min_messages=LOG",
          ]

          port {
            name           = "postgres"
            container_port = 5432
          }

          env {
            name = "POSTGRES_USER"
            value_from {
              secret_key_ref {
                name = var.secret_name
                key  = "DB_USER"
              }
            }
          }

          env {
            name = "POSTGRES_PASSWORD"
            value_from {
              secret_key_ref {
                name = var.secret_name
                key  = "DB_PASSWORD"
              }
            }
          }

          env {
            name = "POSTGRES_DB"
            value_from {
              config_map_key_ref {
                name = var.configmap_name
                key  = "DB_NAME"
              }
            }
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "256Mi"
            }
            limits = {
              memory = "512Mi"
            }
          }

          readiness_probe {
            exec {
              command = [
                "sh",
                "-c",
                "pg_isready -d \"$POSTGRES_DB\" -U \"$POSTGRES_USER\"",
              ]
            }
            initial_delay_seconds = 10
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 10
          }

          liveness_probe {
            exec {
              command = [
                "sh",
                "-c",
                "pg_isready -d \"$POSTGRES_DB\" -U \"$POSTGRES_USER\"",
              ]
            }
            initial_delay_seconds = 20
            period_seconds        = 20
            timeout_seconds       = 5
            failure_threshold     = 6
          }

          volume_mount {
            name       = "data"
            mount_path = "/var/lib/postgresql/data"
          }
        }

        volume {
          name = "data"

          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.this.metadata[0].name
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

