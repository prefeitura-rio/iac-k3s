resource "kubernetes_namespace_v1" "dozzle" {
  metadata {
    name = "dozzle"
  }
}

resource "kubernetes_service_account_v1" "dozzle" {
  metadata {
    name      = "pod-viewer"
    namespace = kubernetes_namespace_v1.dozzle.metadata[0].name
  }
}

resource "kubernetes_cluster_role_v1" "dozzle" {
  metadata {
    name = "pod-viewer-role"
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "pods/log", "nodes"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "replicasets", "daemonsets", "statefulsets"]
    verbs      = ["get"]
  }

  rule {
    api_groups = ["batch"]
    resources  = ["jobs", "cronjobs"]
    verbs      = ["get"]
  }

  rule {
    api_groups = ["metrics.k8s.io"]
    resources  = ["pods"]
    verbs      = ["get", "list"]
  }
}

resource "kubernetes_cluster_role_binding_v1" "dozzle" {
  metadata {
    name = "pod-viewer-binding"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.dozzle.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.dozzle.metadata[0].name
    namespace = kubernetes_service_account_v1.dozzle.metadata[0].namespace
  }
}

resource "kubernetes_persistent_volume_claim_v1" "dozzle_data" {
  wait_until_bound = false

  metadata {
    name      = "dozzle-data"
    namespace = kubernetes_namespace_v1.dozzle.metadata[0].name
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "local-path"

    resources {
      requests = {
        storage = "1Gi"
      }
    }
  }
}

resource "kubernetes_deployment_v1" "dozzle" {
  metadata {
    name      = "dozzle"
    namespace = kubernetes_namespace_v1.dozzle.metadata[0].name
    labels = {
      app = "dozzle"
    }
  }

  spec {
    replicas = 1

    strategy {
      type = "Recreate"
    }

    selector {
      match_labels = {
        app = "dozzle"
      }
    }

    template {
      metadata {
        labels = {
          app = "dozzle"
        }
      }

      spec {
        service_account_name = kubernetes_service_account_v1.dozzle.metadata[0].name

        container {
          name              = "dozzle"
          image             = "amir20/dozzle:v11.3.0"
          image_pull_policy = "IfNotPresent"

          port {
            container_port = 8080
            protocol       = "TCP"
          }

          env {
            name  = "DOZZLE_MODE"
            value = "k8s"
          }

          env {
            name  = "DOZZLE_ENABLE_MCP"
            value = "true"
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "256Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }

          volume_mount {
            name       = "data"
            mount_path = "/data"
          }
        }

        volume {
          name = "data"

          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.dozzle_data.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "dozzle" {
  metadata {
    name      = "dozzle"
    namespace = kubernetes_namespace_v1.dozzle.metadata[0].name
  }

  spec {
    selector = {
      app = "dozzle"
    }

    port {
      port        = 8080
      target_port = 8080
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}

resource "kubectl_manifest" "dozzle_tailscale_ingress" {
  depends_on = [helm_release.tailscale_operator, kubernetes_service_v1.dozzle]

  yaml_body = yamlencode({
    apiVersion = "networking.k8s.io/v1"
    kind       = "Ingress"
    metadata = {
      name      = "dozzle-${var.tailscale.suffix}"
      namespace = kubernetes_namespace_v1.dozzle.metadata[0].name
      annotations = {
        "tailscale.com/tags"     = "tag:k8s-${var.tailscale.suffix},tag:dozzle"
        "tailscale.com/hostname" = "dozzle-${var.tailscale.suffix}"
      }
    }
    spec = {
      ingressClassName = "tailscale"
      defaultBackend = {
        service = {
          name = kubernetes_service_v1.dozzle.metadata[0].name
          port = {
            number = 8080
          }
        }
      }
      tls = [{
        hosts = ["dozzle-${var.tailscale.suffix}.${var.tailscale.domain}"]
      }]
    }
  })
}
