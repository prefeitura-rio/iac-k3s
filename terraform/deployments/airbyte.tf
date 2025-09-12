resource "helm_release" "airbyte" {
  name             = "airbyte"
  repository       = "https://airbytehq.github.io/helm-charts"
  chart            = "airbyte"
  version          = "1.8.2"
  namespace        = "airbyte"
  create_namespace = true
  timeout          = 3600

  set = [
    {
      name  = "global.airbyteUrl"
      value = "airbyte.${var.tailscale.domain}"
    },
    {
      name  = "global.auth.enabled"
      value = "false"
    },
    {
      name  = "webapp.enabled"
      value = "true"
    },
    {
      name  = "webapp.image.repository"
      value = "airbyte/webapp"
    },
    {
      name  = "webapp.image.tag"
      value = "1.7.4"
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
        "tailscale.com/tags"     = "tag:k8s-${var.tailscale.suffix}"
        "tailscale.com/hostname" = "airbyte"
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
            "airbyte.${var.tailscale.domain}"
          ]
        }
      ]
    }
  })
}
