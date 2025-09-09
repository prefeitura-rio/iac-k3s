resource "helm_release" "airbyte" {
  name             = "airbyte"
  repository       = "https://airbytehq.github.io/helm-charts"
  chart            = "airbyte"
  version          = "1.8.2"
  namespace        = "airbyte"
  create_namespace = true

  set = [
    {
      name  = "global.airbyteUrl"
      value = "airbyte.${var.tailscale.tailnet}"
    },
    {
      name  = "global.auth.enabled"
      value = "false"
    },
    {
      name  = "webapp.enabled"
      value = "true"
    }
  ]
}

resource "kubectl_manifest" "airbyte_tailscale_ingress" {
  depends_on = [helm_release.tailscale_operator]
  yaml_body = yamlencode({
    apiVersion = "networking.k8s.io/v1"
    kind       = "Ingress"

    metadata = {
      name      = "airbyte"
      namespace = helm_release.airbyte.namespace
      annotations = {
        "tailscale.com/tags"     = "tag:k8s-iplan"
        "tailscale.com/hostname" = "airbyte-k3s"
      }
    }

    spec = {
      ingressClassName = "tailscale"
      defaultBackend = {
        service = {
          name = "airbyte-airbyte-webapp-svc"
          port = {
            number = 80
          }
        }
      }

      tls = [
        {
          hosts = [
            "airbyte.${var.tailscale.tailnet}"
          ]
        }
      ]
    }
  })
}
