resource "kubernetes_cluster_role" "proxy_clusterrole_kubeapiserver" {
  metadata {
    name = "proxy-clusterrole-kubeapiserver"
  }

  rule {
    api_groups = [""]
    resources = [
      "nodes/metrics",
      "nodes/proxy",
      "nodes/stats",
      "nodes/log",
      "nodes/spec"
    ]
    verbs = ["get", "list", "watch", "create"]
  }
}

resource "kubernetes_cluster_role_binding" "proxy_role_binding_kubernetes_master" {
  metadata {
    name = "proxy-role-binding-kubernetes-master"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "proxy-clusterrole-kubeapiserver"
  }

  subject {
    api_group = "rbac.authorization.k8s.io"
    kind      = "User"
    name      = "kube-apiserver"
  }
}

resource "kubernetes_namespace" "cattle_system" {
  metadata {
    name = "cattle-system"
  }
}

resource "kubernetes_service_account" "cattle" {
  metadata {
    name      = "cattle"
    namespace = kubernetes_namespace.cattle_system.metadata[0].name
  }
}

resource "kubernetes_cluster_role" "cattle_admin" {
  metadata {
    name = "cattle-admin"
    labels = {
      "cattle.io/creator" = "norman"
    }
  }

  rule {
    api_groups = ["*"]
    resources  = ["*"]
    verbs      = ["*"]
  }

  rule {
    non_resource_urls = ["*"]
    verbs             = ["*"]
  }
}

resource "kubernetes_cluster_role_binding" "cattle_admin_binding" {
  metadata {
    name = "cattle-admin-binding"
    labels = {
      "cattle.io/creator" = "norman"
    }
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.cattle_admin.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.cattle.metadata[0].name
    namespace = kubernetes_namespace.cattle_system.metadata[0].name
  }
}

resource "kubernetes_secret" "cattle_credentials" {
  metadata {
    name      = "cattle-credentials-af0ea9843c"
    namespace = kubernetes_namespace.cattle_system.metadata[0].name
  }

  type = "Opaque"

  data = {
    url       = var.rancher.url
    token     = var.rancher.token
    namespace = ""
  }
}

resource "kubernetes_deployment" "cattle_cluster_agent" {
  depends_on = [
    kubernetes_cluster_role_binding.cattle_admin_binding,
    kubernetes_secret.cattle_credentials,
    kubectl_manifest.rancher_egress_service
  ]

  metadata {
    name      = "cattle-cluster-agent"
    namespace = kubernetes_namespace.cattle_system.metadata[0].name
    annotations = {
      "management.cattle.io/scale-available" = "2"
    }
  }

  spec {
    selector {
      match_labels = {
        app = "cattle-cluster-agent"
      }
    }

    template {
      metadata {
        labels = {
          app = "cattle-cluster-agent"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.cattle.metadata[0].name

        affinity {
          node_affinity {
            preferred_during_scheduling_ignored_during_execution {
              weight = 100
              preference {
                match_expressions {
                  key      = "node-role.kubernetes.io/controlplane"
                  operator = "In"
                  values   = ["true"]
                }
              }
            }

            preferred_during_scheduling_ignored_during_execution {
              weight = 100
              preference {
                match_expressions {
                  key      = "node-role.kubernetes.io/control-plane"
                  operator = "In"
                  values   = ["true"]
                }
              }
            }

            preferred_during_scheduling_ignored_during_execution {
              weight = 1
              preference {
                match_expressions {
                  key      = "cattle.io/cluster-agent"
                  operator = "In"
                  values   = ["true"]
                }
              }
            }

            required_during_scheduling_ignored_during_execution {
              node_selector_term {
                match_expressions {
                  key      = "kubernetes.io/os"
                  operator = "NotIn"
                  values   = ["windows"]
                }
              }
            }
          }

          pod_anti_affinity {
            preferred_during_scheduling_ignored_during_execution {
              weight = 100
              pod_affinity_term {
                label_selector {
                  match_expressions {
                    key      = "app"
                    operator = "In"
                    values   = ["cattle-cluster-agent"]
                  }
                }
                topology_key = "kubernetes.io/hostname"
              }
            }
          }
        }

        toleration {
          effect = "NoSchedule"
          key    = "node-role.kubernetes.io/controlplane"
          value  = "true"
        }

        toleration {
          effect   = "NoSchedule"
          key      = "node-role.kubernetes.io/control-plane"
          operator = "Exists"
        }

        container {
          name              = "cluster-register"
          image             = "rancher/rancher-agent:v2.12.1"
          image_pull_policy = "IfNotPresent"

          env {
            name  = "CATTLE_SERVER"
            value = var.rancher.url
          }

          env {
            name  = "CATTLE_CA_CHECKSUM"
            value = var.rancher.checksum
          }

          env {
            name  = "CATTLE_CLUSTER"
            value = "true"
          }

          env {
            name  = "CATTLE_K8S_MANAGED"
            value = "true"
          }

          env {
            name  = "CATTLE_CLUSTER_REGISTRY"
            value = ""
          }

          env {
            name  = "CATTLE_CREDENTIAL_NAME"
            value = kubernetes_secret.cattle_credentials.metadata[0].name
          }

          env {
            name  = "CATTLE_SUC_APP_NAME_OVERRIDE"
            value = ""
          }

          env {
            name  = "CATTLE_SERVER_VERSION"
            value = "v2.12.1"
          }

          env {
            name  = "CATTLE_INSTALL_UUID"
            value = var.rancher.install_uuid
          }

          env {
            name  = "CATTLE_INGRESS_IP_DOMAIN"
            value = "sslip.io"
          }

          env {
            name  = "STRICT_VERIFY"
            value = "false"
          }

          volume_mount {
            name       = "cattle-credentials"
            mount_path = "/cattle-credentials"
            read_only  = true
          }
        }

        volume {
          name = "cattle-credentials"
          secret {
            secret_name  = kubernetes_secret.cattle_credentials.metadata[0].name
            default_mode = "0320"
          }
        }
      }
    }

    strategy {
      type = "RollingUpdate"
      rolling_update {
        max_unavailable = "0"
        max_surge       = "1"
      }
    }
  }
}

resource "kubernetes_service" "cattle_cluster_agent" {
  depends_on = [kubernetes_deployment.cattle_cluster_agent]

  metadata {
    name      = "cattle-cluster-agent"
    namespace = kubernetes_namespace.cattle_system.metadata[0].name
  }

  spec {
    selector = {
      app = "cattle-cluster-agent"
    }

    port {
      name        = "http"
      port        = 80
      target_port = 80
      protocol    = "TCP"
    }

    port {
      name        = "https-internal"
      port        = 443
      target_port = 444
      protocol    = "TCP"
    }
  }
}

resource "kubectl_manifest" "rancher_egress_service" {
  depends_on = [kubectl_manifest.tailscale_egress_proxyclass]
  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "Service"
    metadata = {
      name      = "rancher-agent-k3s"
      namespace = kubernetes_namespace.cattle_system.metadata[0].name
      annotations = {
        "tailscale.com/proxy-class"  = "egress"
        "tailscale.com/tags"         = "tag:k8s-${var.tailscale.suffix}"
        "tailscale.com/tailnet-fqdn" = "rancher.${var.tailscale.domain}"
      }
    }
    spec = {
      type         = "ExternalName"
      externalName = "placeholder"
    }
  })
}
