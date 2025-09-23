resource "helm_release" "kubernetes_dashboard" {
  name       = "kubernetes-dashboard"
  repository = "https://kubernetes.github.io/dashboard/"
  chart      = "kubernetes-dashboard"
  namespace  = "kubernetes-dashboard"
  version    = "7.10.0"

  create_namespace = true

  values = [
    yamlencode({
      app = {
        mode = "dashboard"
        scheduling = {
          nodeSelector = {
            "kubernetes.io/os" = "linux"
          }
        }
        ingress = {
          enabled = false
        }
      }

      nginx = {
        enabled = false
      }

      "cert-manager" = {
        enabled = false
      }

      "metrics-server" = {
        enabled = false
      }

      metricsScraper = {
        enabled = true
      }

      kong = {
        enabled = true
        env = {
          dns_order              = "LAST,A,CNAME,AAAA,SRV"
          plugins                = "off"
          nginx_worker_processes = 1
        }
        ingressController = {
          enabled = false
        }
        manager = {
          enabled = false
        }
        proxy = {
          type = "ClusterIP"
          http = {
            enabled = false
          }
        }
      }
    })
  ]
}

resource "kubernetes_service_account" "dashboard_admin" {
  metadata {
    name      = "dashboard-admin"
    namespace = helm_release.kubernetes_dashboard.namespace
  }
}

resource "kubernetes_cluster_role_binding" "dashboard_admin" {
  metadata {
    name = "dashboard-admin"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.dashboard_admin.metadata[0].name
    namespace = kubernetes_service_account.dashboard_admin.metadata[0].namespace
  }
}

resource "kubernetes_secret" "dashboard_admin_token" {
  metadata {
    name      = "dashboard-admin-token"
    namespace = helm_release.kubernetes_dashboard.namespace
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account.dashboard_admin.metadata[0].name
    }
  }

  type = "kubernetes.io/service-account-token"
}

resource "kubectl_manifest" "dashboard_tailscale_ingress" {
  depends_on = [helm_release.tailscale_operator, helm_release.kubernetes_dashboard]
  yaml_body = yamlencode({
    apiVersion = "networking.k8s.io/v1"
    kind       = "Ingress"

    metadata = {
      name      = "kubernetes-dashboard"
      namespace = helm_release.kubernetes_dashboard.namespace
      annotations = {
        "tailscale.com/tags"     = "tag:k8s-${var.tailscale.suffix}"
        "tailscale.com/hostname" = "dashboard-${var.tailscale.suffix}"
      }
    }

    spec = {
      ingressClassName = "tailscale"
      defaultBackend = {
        service = {
          name = "kubernetes-dashboard-kong-proxy"
          port = {
            number = 443
          }
        }
      }

      tls = [
        {
          hosts = [
            "dashboard-${var.tailscale.suffix}.${var.tailscale.domain}"
          ]
        }
      ]
    }
  })
}

