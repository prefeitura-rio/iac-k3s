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
    },
    {
      name  = "global.jobs.resources.requests.cpu"
      value = "500m"
    },
    {
      name  = "global.jobs.resources.requests.memory"
      value = "1Gi"
    },
    {
      name  = "global.jobs.resources.limits.cpu"
      value = "1"
    },
    {
      name  = "global.jobs.resources.limits.memory"
      value = "2Gi"
    },
    {
      name  = "workload-launcher.resources.requests.cpu"
      value = "250m"
    },
    {
      name  = "workload-launcher.resources.requests.memory"
      value = "512Mi"
    },
    {
      name  = "workload-launcher.resources.limits.cpu"
      value = "500m"
    },
    {
      name  = "workload-launcher.resources.limits.memory"
      value = "1Gi"
    },
    {
      name  = "server.resources.requests.cpu"
      value = "250m"
    },
    {
      name  = "server.resources.requests.memory"
      value = "512Mi"
    },
    {
      name  = "server.resources.limits.cpu"
      value = "500m"
    },
    {
      name  = "server.resources.limits.memory"
      value = "1Gi"
    },
    {
      name  = "worker.resources.requests.cpu"
      value = "250m"
    },
    {
      name  = "worker.resources.requests.memory"
      value = "512Mi"
    },
    {
      name  = "worker.resources.limits.cpu"
      value = "500m"
    },
    {
      name  = "worker.resources.limits.memory"
      value = "1Gi"
    },
    {
      name  = "webapp.resources.requests.cpu"
      value = "100m"
    },
    {
      name  = "webapp.resources.requests.memory"
      value = "256Mi"
    },
    {
      name  = "webapp.resources.limits.cpu"
      value = "200m"
    },
    {
      name  = "webapp.resources.limits.memory"
      value = "512Mi"
    },
    {
      name  = "cron.resources.requests.cpu"
      value = "100m"
    },
    {
      name  = "cron.resources.requests.memory"
      value = "256Mi"
    },
    {
      name  = "cron.resources.limits.cpu"
      value = "200m"
    },
    {
      name  = "cron.resources.limits.memory"
      value = "512Mi"
    },
    {
      name  = "connector-builder-server.resources.requests.cpu"
      value = "100m"
    },
    {
      name  = "connector-builder-server.resources.requests.memory"
      value = "256Mi"
    },
    {
      name  = "connector-builder-server.resources.limits.cpu"
      value = "200m"
    },
    {
      name  = "connector-builder-server.resources.limits.memory"
      value = "512Mi"
    },
    {
      name  = "workload-api-server.resources.requests.cpu"
      value = "100m"
    },
    {
      name  = "workload-api-server.resources.requests.memory"
      value = "256Mi"
    },
    {
      name  = "workload-api-server.resources.limits.cpu"
      value = "200m"
    },
    {
      name  = "workload-api-server.resources.limits.memory"
      value = "512Mi"
    },
    {
      name  = "temporal.resources.requests.cpu"
      value = "200m"
    },
    {
      name  = "temporal.resources.requests.memory"
      value = "512Mi"
    },
    {
      name  = "temporal.resources.limits.cpu"
      value = "400m"
    },
    {
      name  = "temporal.resources.limits.memory"
      value = "1Gi"
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
