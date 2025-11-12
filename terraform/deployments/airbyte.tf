resource "helm_release" "airbyte" {
  name             = "airbyte"
  repository       = "https://airbytehq.github.io/charts"
  chart            = "airbyte"
  version          = "2.0.19"
  namespace        = "airbyte"
  create_namespace = true
  timeout          = 3600

  values = [
    templatefile("${path.module}/yamls/airbyte-values.yaml", {
      airbyte_url = "airbyte.${var.tailscale.domain}"
      edition     = "community"
    })
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
        "tailscale.com/tags"     = "tag:k8s-${var.tailscale.suffix},tag:airbyte"
        "tailscale.com/hostname" = "airbyte"
      }
    }

    spec = {
      ingressClassName = "tailscale"
      defaultBackend = {
        service = {
          name = "airbyte-airbyte-server-svc"
          port = {
            number = 8001
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
