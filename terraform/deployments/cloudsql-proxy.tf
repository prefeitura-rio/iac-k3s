resource "kubernetes_namespace" "cloudsql_proxy" {
  metadata {
    name = "cloudsql-proxy"
  }
}

resource "kubernetes_config_map" "cloudsql_proxy" {
  for_each = var.cloudsql_proxies

  metadata {
    name      = "${each.key}-config"
    namespace = kubernetes_namespace.cloudsql_proxy.metadata[0].name
  }
  data = {
    CLOUD_SQL_INSTANCE_NAME   = each.value.instance_name
    CLOUD_SQL_INSTANCE_REGION = each.value.instance_region
    CLOUD_SQL_PROJECT_ID      = each.value.project_id
  }
}

resource "kubernetes_secret" "cloudsql_proxy" {
  for_each = var.cloudsql_proxies

  metadata {
    name      = "${each.key}-sa-key"
    namespace = kubernetes_namespace.cloudsql_proxy.metadata[0].name
  }
  data = {
    "service-account-key.json" = base64decode(each.value.sa_key)
  }
}

resource "kubernetes_deployment" "cloudsql_proxy" {
  for_each = var.cloudsql_proxies

  metadata {
    labels = {
      app = each.key
    }
    name      = each.key
    namespace = kubernetes_namespace.cloudsql_proxy.metadata[0].name
  }

  spec {
    selector {
      match_labels = {
        app = each.key
      }
    }
    replicas = 1
    template {
      metadata {
        labels = {
          app = each.key
        }
      }
      spec {
        container {
          name  = each.key
          image = "gcr.io/cloud-sql-connectors/cloud-sql-proxy:2.14.1"
          port {
            container_port = each.value.port
            protocol       = "TCP"
          }
          env_from {
            config_map_ref {
              name = kubernetes_config_map.cloudsql_proxy[each.key].metadata[0].name
            }
          }
          args = [
            "--structured-logs",
            "--port=${each.value.port}",
            "--address=0.0.0.0",
            "--private-ip",
            "--credentials-file=/var/secrets/google/service-account-key.json",
            "$(CLOUD_SQL_PROJECT_ID):$(CLOUD_SQL_INSTANCE_REGION):$(CLOUD_SQL_INSTANCE_NAME)"
          ]
          volume_mount {
            name       = "service-account-key"
            mount_path = "/var/secrets/google"
            read_only  = true
          }
          security_context {
            run_as_non_root = true
          }
          resources {
            requests = {
              memory = "128Mi"
              cpu    = "100m"
            }
            limits = {
              memory = "256Mi"
              cpu    = "500m"
            }
          }
        }
        volume {
          name = "service-account-key"
          secret {
            secret_name = kubernetes_secret.cloudsql_proxy[each.key].metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "cloudsql_proxy" {
  for_each = var.cloudsql_proxies

  depends_on = [kubernetes_deployment.cloudsql_proxy]

  metadata {
    labels = {
      app = each.key
    }
    name      = each.key
    namespace = kubernetes_namespace.cloudsql_proxy.metadata[0].name
  }
  spec {
    selector = {
      app = each.key
    }
    port {
      port        = each.value.port
      protocol    = "TCP"
      name        = each.key
      target_port = each.value.port
    }
    type = "ClusterIP"
  }
}
