locals {
  labels = merge(var.labels, {
    "app.kubernetes.io/component" = "repository"
  })

  # The keystore settings come from the existing manifest, so they stay aligned
  # with the keystore shipped inside the container image. The two passwords are
  # not in this string: they are resolved by Kubernetes from the Secret and
  # substituted into the $(...) references at container start.
  java_tool_options = join(" ", concat(
    [
      for key in sort(keys(var.keystore_properties)) :
      "-D${key}=${var.keystore_properties[key]}"
      if var.keystore_properties[key] != null
    ],
    [
      "-Dmetadata-keystore.password=$(METADATA_KEYSTORE_PASSWORD)",
      "-Dmetadata-keystore.metadata.password=$(METADATA_KEYSTORE_METADATA_PASSWORD)",
    ],
  ))

  java_opts = join(" ", [
    "-Ddb.driver=org.postgresql.Driver",
    "-Ddb.username=$(DB_USER)",
    "-Ddb.password=$(DB_PASSWORD)",
    "-Ddb.url=jdbc:postgresql://${var.postgres_service}:5432/$(DB_NAME)",
    "-Dsolr.secureComms=secret",
    "-Dsolr.sharedSecret=$(TRANSFORM_SHARED_SECRET)",
    "-Dindex.subsystem.name=elasticsearch",
    "-Delasticsearch.createIndexIfNotExists=true",
    "-Delasticsearch.host=${var.elasticsearch_service}",
    "-Delasticsearch.port=9200",
    "-Dshare.host=$(ALFRESCO_PUBLIC_HOST)",
    "-Dshare.port=$(SHARE_PORT)",
    "-Dalfresco.host=$(ALFRESCO_PUBLIC_HOST)",
    "-Dalfresco.port=$(ALFRESCO_PORT)",
    "-Dcsrf.filter.enabled=false",
    "-Daos.baseUrlOverwrite=http://$(ALFRESCO_PUBLIC_HOST):$(ALFRESCO_PORT)/alfresco/aos",
    "-Dmessaging.broker.url=\"failover:(nio://${var.activemq_service}:61616)?timeout=3000&jms.useCompression=true\"",
    "-Dmessaging.broker.username=$(ACTIVEMQ_USER)",
    "-Dmessaging.broker.password=$(ACTIVEMQ_PASSWORD)",
    # ACS 26.2 only accepts DEFAULT, INSTALLER, DOCKER_COMPOSE, HELM_CHART,
    # ANSIBLE or QUICK_START. KUBERNETES is not a member of that enum and
    # aborts the Spring context.
    "-Ddeployment.method=DEFAULT",
    "-DlocalTransform.core-aio.url=http://${var.transform_core_service}:8090/",
    "-XX:MinRAMPercentage=50",
    "-XX:MaxRAMPercentage=80",
  ])
}

resource "kubernetes_persistent_volume_claim" "this" {
  metadata {
    name      = "alfresco-data"
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
    name      = "alfresco"
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
    name      = "alfresco"
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    replicas = 1

    # First boot loads the schema and stays unready well past the 600s
    # Kubernetes default, which marks the Deployment failed while it is
    # still starting.
    progress_deadline_seconds = 1800

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

        # The content store is owned by the tomcat user in the image; the
        # init container opens it up before the main container starts.
        init_container {
          name              = "fix-contentstore-permissions"
          image             = var.busybox_image
          image_pull_policy = "IfNotPresent"

          command = [
            "sh",
            "-c",
            "chmod -R a+rwx /usr/local/tomcat/alf_data",
          ]

          security_context {
            run_as_user = 0
          }

          volume_mount {
            name       = "data"
            mount_path = "/usr/local/tomcat/alf_data"
          }
        }

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
              "until nc -z ${var.postgres_service} 5432; do echo \"attente de postgres\"; sleep 2; done",
              "until nc -z ${var.activemq_service} 61616; do echo \"attente d'activemq\"; sleep 2; done",
              "until wget -q -O- http://${var.elasticsearch_service}:9200/_cluster/health | grep -E -q 'green|yellow'; do echo \"attente d'elasticsearch\"; sleep 3; done",
            ]),
          ]
        }

        container {
          name              = "alfresco"
          image             = var.image
          image_pull_policy = "IfNotPresent"

          port {
            name           = "http"
            container_port = 8080
          }

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
            name = "ACTIVEMQ_USER"
            value_from {
              secret_key_ref {
                name = var.secret_name
                key  = "ACTIVEMQ_USER"
              }
            }
          }

          env {
            name = "ACTIVEMQ_PASSWORD"
            value_from {
              secret_key_ref {
                name = var.secret_name
                key  = "ACTIVEMQ_PASSWORD"
              }
            }
          }

          # The keystore passwords are injected as environment variables and
          # referenced from JAVA_TOOL_OPTIONS. The Deployment definition
          # therefore never contains the secret values.
          env {
            name = "METADATA_KEYSTORE_PASSWORD"
            value_from {
              secret_key_ref {
                name = var.secret_name
                key  = "METADATA_KEYSTORE_PASSWORD"
              }
            }
          }

          env {
            name = "METADATA_KEYSTORE_METADATA_PASSWORD"
            value_from {
              secret_key_ref {
                name = var.secret_name
                key  = "METADATA_KEYSTORE_METADATA_PASSWORD"
              }
            }
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
            name  = "JAVA_TOOL_OPTIONS"
            value = local.java_tool_options
          }

          env {
            name  = "JAVA_OPTS"
            value = local.java_opts
          }

          resources {
            requests = {
              cpu    = "500m"
              memory = "1Gi"
            }
            limits = {
              memory = "1900Mi"
            }
          }

          startup_probe {
            http_get {
              path = "/alfresco/api/-default-/public/alfresco/versions/1/probes/-ready-"
              port = "http"
            }
            period_seconds    = 20
            timeout_seconds   = 5
            failure_threshold = 40
          }

          readiness_probe {
            http_get {
              path = "/alfresco/api/-default-/public/alfresco/versions/1/probes/-ready-"
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

          volume_mount {
            name       = "data"
            mount_path = "/usr/local/tomcat/alf_data"
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

