resource "kubernetes_namespace_v1" "jwks_mirror" {
  metadata {
    name = "jwks-mirror"
  }
}

resource "kubernetes_config_map_v1" "jwks_mirror_nginx" {
  metadata {
    name      = "jwks-mirror-nginx"
    namespace = kubernetes_namespace_v1.jwks_mirror.metadata[0].name
  }

  data = {
    "default.conf" = <<-EOF
      proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=jwks_cache:1m max_size=10m inactive=30d use_temp_path=off;

      server {
        listen 8080;

        location = /realms/rio/protocol/openid-connect/certs {
          proxy_pass https://id-staging.rio.gov.br/realms/rio/protocol/openid-connect/certs;
          proxy_ssl_server_name on;
          proxy_set_header Host id-staging.rio.gov.br;

          proxy_cache jwks_cache;
          proxy_cache_key $uri;
          proxy_cache_valid 200 1h;

          # Serve the last known-good response (even if stale) when the
          # public endpoint is unreachable or erroring, instead of failing
          # the request outright. This is the whole point of the mirror.
          proxy_cache_use_stale error timeout http_500 http_502 http_503 http_504;
          proxy_cache_background_update on;
          proxy_cache_lock on;

          add_header X-Cache-Status $upstream_cache_status always;
        }

        location = /healthz {
          return 200 "ok\n";
          add_header Content-Type text/plain;
        }
      }
    EOF
  }
}

resource "kubernetes_deployment_v1" "jwks_mirror" {
  metadata {
    name      = "jwks-mirror"
    namespace = kubernetes_namespace_v1.jwks_mirror.metadata[0].name
    labels = {
      app = "jwks-mirror"
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "jwks-mirror"
      }
    }

    template {
      metadata {
        labels = {
          app = "jwks-mirror"
        }
      }

      spec {
        container {
          name  = "nginx"
          image = "nginx:1.27-alpine"

          port {
            name           = "http"
            container_port = 8080
            protocol       = "TCP"
          }

          volume_mount {
            name       = "config"
            mount_path = "/etc/nginx/conf.d/default.conf"
            sub_path   = "default.conf"
            read_only  = true
          }

          volume_mount {
            name       = "cache"
            mount_path = "/var/cache/nginx"
          }

          volume_mount {
            name       = "run"
            mount_path = "/var/run"
          }

          resources {
            requests = {
              cpu    = "50m"
              memory = "32Mi"
            }
            limits = {
              cpu    = "200m"
              memory = "128Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/healthz"
              port = 8080
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/healthz"
              port = 8080
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }
        }

        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map_v1.jwks_mirror_nginx.metadata[0].name
          }
        }

        volume {
          name = "cache"
          empty_dir {}
        }

        volume {
          name = "run"
          empty_dir {}
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "jwks_mirror" {
  metadata {
    name      = "jwks-mirror"
    namespace = kubernetes_namespace_v1.jwks_mirror.metadata[0].name
    labels = {
      app = "jwks-mirror"
    }
  }

  spec {
    selector = {
      app = "jwks-mirror"
    }

    port {
      name        = "http"
      port        = 8080
      target_port = 8080
      protocol    = "TCP"
    }
  }
}

resource "kubectl_manifest" "jwks_mirror_tailscale_ingress" {
  depends_on = [helm_release.tailscale_operator]
  yaml_body = yamlencode({
    apiVersion = "networking.k8s.io/v1"
    kind       = "Ingress"

    metadata = {
      name      = "jwks-mirror"
      namespace = kubernetes_namespace_v1.jwks_mirror.metadata[0].name
      annotations = {
        "tailscale.com/tags"     = "tag:k8s-${var.tailscale.suffix},tag:jwks-mirror"
        "tailscale.com/hostname" = "jwks-mirror"
      }
    }

    spec = {
      ingressClassName = "tailscale"
      defaultBackend = {
        service = {
          name = kubernetes_service_v1.jwks_mirror.metadata[0].name
          port = {
            number = 8080
          }
        }
      }

      tls = [
        {
          hosts = [
            "jwks-mirror.${var.tailscale.domain}"
          ]
        }
      ]
    }
  })
}

resource "kubectl_manifest" "jwks_mirror_intranet_ingress" {
  depends_on = [kubectl_manifest.internal_ca_issuer]
  yaml_body = yamlencode({
    apiVersion = "networking.k8s.io/v1"
    kind       = "Ingress"

    metadata = {
      name      = "jwks-mirror-intranet"
      namespace = kubernetes_namespace_v1.jwks_mirror.metadata[0].name
      annotations = {
        "cert-manager.io/cluster-issuer" = "internal-ca-issuer"
      }
    }

    spec = {
      ingressClassName = "traefik"
      rules = [
        {
          host = var.jwks_mirror_public_hostname
          http = {
            paths = [
              {
                path     = "/"
                pathType = "Prefix"
                backend = {
                  service = {
                    name = kubernetes_service_v1.jwks_mirror.metadata[0].name
                    port = {
                      number = 8080
                    }
                  }
                }
              }
            ]
          }
        }
      ]
      tls = [
        {
          hosts      = [var.jwks_mirror_public_hostname]
          secretName = "jwks-mirror-public-tls"
        }
      ]
    }
  })
}
