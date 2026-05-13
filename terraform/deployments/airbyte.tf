resource "helm_release" "airbyte" {
  name             = "airbyte"
  repository       = "https://airbytehq.github.io/charts"
  chart            = "airbyte"
  version          = "2.0.19"
  namespace        = "airbyte"
  create_namespace = true
  timeout          = 3600

  values = [yamlencode({
    global = {
      airbyteUrl = "airbyte.${var.tailscale.domain}"
      edition    = "community"
      auth       = { enabled = false }
    }
    server = {
      nodeSelector = { "kubernetes.io/hostname" = "k3s-worker-2" }
      resources = {
        requests = { cpu = "500m", memory = "2Gi" }
        limits   = { cpu = "1000m", memory = "4Gi" }
      }
    }
    temporal = {
      nodeSelector = { "kubernetes.io/hostname" = "k3s-worker-2" }
      resources = {
        requests = { cpu = "300m", memory = "1Gi" }
        limits   = { cpu = "1000m", memory = "2Gi" }
      }
    }
    workloadLauncher = {
      nodeSelector = { "kubernetes.io/hostname" = "k3s-worker-2" }
      resources = {
        requests = { cpu = "500m", memory = "2Gi" }
        limits   = { cpu = "2000m", memory = "4Gi" }
      }
    }
    podSweeper = {
      nodeSelector = { "kubernetes.io/hostname" = "k3s-worker-2" }
      resources = {
        requests = { cpu = "50m", memory = "128Mi" }
        limits   = { cpu = "200m", memory = "256Mi" }
      }
    }
    metrics = {
      nodeSelector = { "kubernetes.io/hostname" = "k3s-worker-2" }
      resources = {
        requests = { cpu = "50m", memory = "128Mi" }
        limits   = { cpu = "200m", memory = "512Mi" }
      }
    }
    cron = {
      nodeSelector = { "kubernetes.io/hostname" = "k3s-worker-2" }
      resources = {
        requests = { cpu = "50m", memory = "128Mi" }
        limits   = { cpu = "800m", memory = "1Gi" }
      }
    }
    workloadApiServer = {
      nodeSelector = { "kubernetes.io/hostname" = "k3s-worker-2" }
      resources = {
        requests = { cpu = "300m", memory = "1Gi" }
        limits   = { cpu = "1000m", memory = "2Gi" }
      }
    }
    airbyteBootloader    = { nodeSelector = { "kubernetes.io/hostname" = "k3s-worker-2" } }
    connectorBuilderServer = { nodeSelector = { "kubernetes.io/hostname" = "k3s-worker-2" } }
  })]
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
