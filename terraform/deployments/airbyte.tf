resource "kubernetes_namespace_v1" "airbyte" {
  metadata {
    name = "airbyte"
  }
}

resource "kubernetes_secret_v1" "airbyte_database_credentials" {
  depends_on = [kubernetes_namespace_v1.airbyte]

  metadata {
    name      = "airbyte-database-credentials"
    namespace = "airbyte"
  }

  data = {
    DATABASE_USER                    = var.airbyte.database.username
    DATABASE_PASSWORD                = var.airbyte.database.password
    CONFIG_DATABASE_REPLICA_USER     = var.airbyte.database.username
    CONFIG_DATABASE_REPLICA_PASSWORD = var.airbyte.database.password
  }
}

resource "kubernetes_secret_v1" "airbyte_gcs_credentials" {
  depends_on = [kubernetes_namespace_v1.airbyte]

  metadata {
    name      = "airbyte-gcs-credentials"
    namespace = "airbyte"
  }

  data = {
    GOOGLE_APPLICATION_CREDENTIALS_JSON = base64decode(var.airbyte.gcs_sa_key)
  }
}

resource "kubectl_manifest" "airbyte_cloudsql_egress_service" {
  depends_on = [helm_release.tailscale_operator]

  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "Service"
    metadata = {
      name      = "cloudsql-proxy"
      namespace = kubernetes_namespace_v1.airbyte.metadata[0].name
      annotations = {
        "tailscale.com/proxy-class"  = "egress"
        "tailscale.com/tags"         = "tag:k8s-${var.tailscale.suffix},tag:airbyte"
        "tailscale.com/tailnet-fqdn" = "cloudsql-proxy.${var.tailscale.domain}"
      }
    }
    spec = {
      type         = "ExternalName"
      externalName = "placeholder"
    }
  })
}

resource "helm_release" "airbyte" {
  depends_on = [
    kubectl_manifest.airbyte_cloudsql_egress_service,
    kubernetes_secret_v1.airbyte_database_credentials,
    kubernetes_secret_v1.airbyte_gcs_credentials,
  ]
  name             = "airbyte"
  repository       = "https://airbytehq.github.io/charts"
  chart            = "airbyte"
  version          = "2.3.0"
  namespace        = "airbyte"
  create_namespace = false
  timeout          = 3600

  values = [yamlencode({
    global = {
      airbyteUrl = "airbyte-${var.tailscale.suffix}.${var.tailscale.domain}"
      edition    = "community"
      auth       = { enabled = false }
      env_vars = {
        MAX_CHECK_WORKERS             = "5"
        MAX_SYNC_WORKERS              = "2"
        WORKLOAD_LAUNCHER_PARALLELISM = "2"
      }
      database = {
        type              = "internal"
        secretName        = "airbyte-database-credentials"
        host              = "cloudsql-proxy.airbyte.svc.cluster.local"
        port              = 5432
        name              = "airbyte"
        userSecretKey     = "DATABASE_USER"
        passwordSecretKey = "DATABASE_PASSWORD"
      }
      storage = {
        type       = "gcs"
        secretName = "airbyte-gcs-credentials"
        bucket = {
          log             = "rj-iplanrio-dia-airbyte"
          auditLogging    = "rj-iplanrio-dia-airbyte"
          state           = "rj-iplanrio-dia-airbyte"
          workloadOutput  = "rj-iplanrio-dia-airbyte"
          activityPayload = "rj-iplanrio-dia-airbyte"
        }
        gcs = {
          credentialsSecretName = "airbyte-gcs-credentials"
        }
      }
    }
    minio = {
      enabled = false
    }
    postgresql = {
      enabled = false
    }
    server = {
      resources = {
        requests = { cpu = "500m", memory = "2Gi" }
        limits   = { cpu = "1000m", memory = "4Gi" }
      }
    }
    temporal = {
      resources = {
        requests = { cpu = "1", memory = "2Gi" }
        limits   = { cpu = "2", memory = "4Gi" }
      }
    }
    workloadLauncher = {
      resources = {
        requests = { cpu = "500m", memory = "2Gi" }
        limits   = { cpu = "2000m", memory = "4Gi" }
      }
    }
    podSweeper = {
      resources = {
        requests = { cpu = "50m", memory = "128Mi" }
        limits   = { cpu = "200m", memory = "256Mi" }
      }
    }
    metrics = {
      resources = {
        requests = { cpu = "50m", memory = "128Mi" }
        limits   = { cpu = "200m", memory = "512Mi" }
      }
    }
    cron = {
      resources = {
        requests = { cpu = "50m", memory = "128Mi" }
        limits   = { cpu = "800m", memory = "1Gi" }
      }
    }
    workloadApiServer = {
      resources = {
        requests = { cpu = "300m", memory = "1Gi" }
        limits   = { cpu = "1000m", memory = "2Gi" }
      }
    }
    airbyteBootloader      = {}
    connectorBuilderServer = {}
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
        "tailscale.com/hostname" = "airbyte-${var.tailscale.suffix}"
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
            "airbyte-${var.tailscale.suffix}.${var.tailscale.domain}"
          ]
        }
      ]
    }
  })
}
