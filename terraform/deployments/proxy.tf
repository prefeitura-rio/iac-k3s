resource "kubernetes_namespace_v1" "proxy" {
  metadata {
    name = "proxy"
  }
}

resource "kubernetes_config_map_v1" "squid_config" {
  metadata {
    name      = "squid-config"
    namespace = kubernetes_namespace_v1.proxy.metadata[0].name
  }

  data = {
    "squid.conf" = <<-EOF
      http_port 3128

      # access control - allow all
      acl all src 0.0.0.0/0

      # allow CONNECT method for SMTP tunneling
      acl CONNECT method CONNECT
      acl smtp_ports port 25 465 587
      http_access allow CONNECT smtp_ports
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

resource "kubernetes_deployment_v1" "squid" {
  metadata {
    name      = "squid"
    namespace = kubernetes_namespace_v1.proxy.metadata[0].name
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
            name = kubernetes_config_map_v1.squid_config.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "squid" {
  metadata {
    name      = "proxy"
    namespace = kubernetes_namespace_v1.proxy.metadata[0].name
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
