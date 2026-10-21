locals {
  labels = merge(var.labels, {
    "app.kubernetes.io/component" = "elasticsearch"
  })
}

resource "kubernetes_persistent_volume_claim" "this" {
  metadata {
    name      = "elasticsearch-data"
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
    name      = "elasticsearch"
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    selector = local.labels

    port {
      name        = "http"
      port        = 9200
      target_port = "http"
    }
  }
}

resource "kubernetes_deployment" "this" {
  metadata {
    name      = "elasticsearch"
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

        security_context {
          fs_group     = 1000
          run_as_user  = 1000
          run_as_group = 1000
        }

        container {
          name              = "elasticsearch"
          image             = var.image
          image_pull_policy = "IfNotPresent"

          port {
            name           = "http"
            container_port = 9200
          }

          env {
            name  = "discovery.type"
            value = "single-node"
          }

          # Security is off in the local stack because the Elasticsearch
          # credentials would have to be wired into ACS and batch-indexing
          # as well. It stays a variable so a secured cluster only needs an
          # override, not a code change.
          env {
            name  = "xpack.security.enabled"
            value = var.security_enabled ? "true" : "false"
          }

          env {
            name  = "ES_JAVA_OPTS"
            value = "-Xms512m -Xmx512m"
          }

          # Avoids the host vm.max_map_count sysctl, often unsettable on a
          # local cluster.
          env {
            name  = "node.store.allow_mmap"
            value = "false"
          }

          env {
            name  = "ingest.geoip.downloader.enabled"
            value = "false"
          }

          security_context {
            capabilities {
              add = ["IPC_LOCK"]
            }
          }

          resources {
            requests = {
              cpu    = "200m"
              memory = "1Gi"
            }
            # Heap is 512m. Elasticsearch also uses off-heap memory, and a 1Gi
            # cgroup limit gets the process killed (exit 137) on Docker Desktop.
            limits = {
              memory = "2Gi"
            }
          }

          startup_probe {
            exec {
              command = [
                "bash",
                "-c",
                "curl -s http://localhost:9200/_cluster/health | grep -qE '\"status\":\"(green|yellow)\"'",
              ]
            }
            period_seconds    = 15
            timeout_seconds   = 10
            failure_threshold = 20
          }

          readiness_probe {
            exec {
              command = [
                "bash",
                "-c",
                "curl -s http://localhost:9200/_cluster/health | grep -qE '\"status\":\"(green|yellow)\"'",
              ]
            }
            period_seconds    = 15
            timeout_seconds   = 10
            failure_threshold = 5
          }

          liveness_probe {
            tcp_socket {
              port = "http"
            }
            period_seconds    = 30
            timeout_seconds   = 5
            failure_threshold = 5
          }

          volume_mount {
            name       = "data"
            mount_path = "/usr/share/elasticsearch/data"
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

