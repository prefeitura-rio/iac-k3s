resource "kubernetes_namespace_v1" "airbyte" {
  metadata {
    name = "airbyte"
  }
}

resource "random_password" "airbyte_database" {
  length  = 32
  special = false
}

resource "kubernetes_secret_v1" "airbyte_database_credentials" {
  depends_on = [kubernetes_namespace_v1.airbyte]

  metadata {
    name      = "airbyte-database-credentials"
    namespace = "airbyte"
  }

  data = {
    DATABASE_USER                    = "airbyte"
    DATABASE_PASSWORD                = random_password.airbyte_database.result
    CONFIG_DATABASE_REPLICA_USER     = "airbyte"
    CONFIG_DATABASE_REPLICA_PASSWORD = random_password.airbyte_database.result
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
    "gcp.json"                          = base64decode(var.airbyte.gcs_sa_key)
  }
}

resource "helm_release" "airbyte" {
  depends_on = [
    helm_release.cloudsql_proxy,
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
      enabled            = true
      postgresqlUsername = "airbyte"
      postgresqlPassword = random_password.airbyte_database.result
      postgresqlDatabase = "airbyte"
      image = {
        repository = "postgres"
        tag        = "17"
      }
      podSecurityContext = {
        fsGroup = 999
      }
      containerSecurityContext = {
        allowPrivilegeEscalation = false
        runAsNonRoot             = true
        runAsUser                = 999
        runAsGroup               = 999
        readOnlyRootFilesystem   = false
        capabilities             = { drop = ["ALL"] }
        seccompProfile           = { type = "RuntimeDefault" }
      }
      storage = {
        volumeClaimValue = "10Gi"
      }
    }
    server = {
      livenessProbe = {
        enabled = false
      }
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
