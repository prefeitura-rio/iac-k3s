resource "helm_release" "signoz" {
  name             = "signoz"
  repository       = "https://charts.signoz.io"
  chart            = "signoz"
  version          = "0.91.1"
  namespace        = "signoz"
  create_namespace = true
  timeout          = 3600
}

resource "helm_release" "signoz_k8s_infra" {
  name       = "k8s-infra"
  repository = "https://charts.signoz.io"
  chart      = "k8s-infra"
  version    = "0.14.1"
  namespace  = helm_release.signoz.namespace

  set = [{
    name  = "otelCollectorEndpoint"
    value = "signoz-otel-collector.${helm_release.signoz.namespace}.svc.cluster.local:4317"
  }]
}

resource "kubectl_manifest" "signoz_tailscale_ingress" {
  depends_on = [helm_release.tailscale_operator]
  yaml_body = yamlencode({
    apiVersion = "networking.k8s.io/v1"
    kind       = "Ingress"

    metadata = {
      name      = "signoz"
      namespace = helm_release.signoz.namespace
      annotations = {
        "tailscale.com/tags"     = "tag:k8s-${var.tailscale.suffix}"
        "tailscale.com/hostname" = "signoz-${var.tailscale.suffix}"
      }
    }

    spec = {
      ingressClassName = "tailscale"
      defaultBackend = {
        service = {
          name = "signoz"
          port = {
            number = 8080
          }
        }
      }

      tls = [
        {
          hosts = [
            "signoz-${var.tailscale.suffix}.${var.tailscale.domain}"
          ]
        }
      ]
    }
  })
}
