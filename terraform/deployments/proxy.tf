resource "kubernetes_namespace" "proxy" {
  metadata {
    name = "proxy"
  }
}

resource "kubernetes_config_map" "squid_config" {
  metadata {
    name      = "squid-config"
    namespace = kubernetes_namespace.proxy.metadata[0].name
  }

  data = {
    "squid.conf" = <<-EOF
      http_port 3128

      # access control - allow all
      acl all src 0.0.0.0/0
      http_access allow all

      # disable caching
      cache deny all

      # add proxy identification headers
      request_header_add X-Forwarded-By "proxy.squirrel-regulus.ts.net" all
      request_header_add Via "1.1 proxy.squirrel-regulus.ts.net (squid)" all

      # logging
      access_log stdio:/var/log/squid/access.log squid
      cache_log /var/log/squid/cache.log

      # direct forwarding (no parent proxy)
      always_direct allow all

      # coredump directory
      coredump_dir /var/spool/squid
    EOF
  }
}

resource "kubernetes_deployment" "squid" {
  metadata {
    name      = "squid"
    namespace = kubernetes_namespace.proxy.metadata[0].name
    labels = {
      app = "squid"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "squid"
      }
    }

    template {
      metadata {
        labels = {
          app = "squid"
        }
      }

      spec {
        container {
          name  = "squid"
          image = "ubuntu/squid:latest"

          port {
            name           = "proxy"
            container_port = 3128
            protocol       = "TCP"
          }

          volume_mount {
            name       = "config"
            mount_path = "/etc/squid/squid.conf"
            sub_path   = "squid.conf"
            read_only  = true
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }

          liveness_probe {
            tcp_socket {
              port = 3128
            }
            initial_delay_seconds = 10
            period_seconds        = 10
          }

          readiness_probe {
            tcp_socket {
              port = 3128
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }
        }

        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map.squid_config.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "squid" {
  metadata {
    name      = "proxy"
    namespace = kubernetes_namespace.proxy.metadata[0].name
    labels = {
      app = "squid"
    }
    annotations = {
      "tailscale.com/tags"     = "tag:k8s-${var.tailscale.suffix},tag:proxy"
      "tailscale.com/hostname" = "proxy"
    }
  }

  spec {
    selector = {
      app = "squid"
    }

    port {
      name        = "proxy"
      port        = 3128
      target_port = 3128
      protocol    = "TCP"
    }

    type                = "LoadBalancer"
    load_balancer_class = "tailscale"
  }
}
