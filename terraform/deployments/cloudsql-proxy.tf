resource "kubernetes_namespace_v1" "cloudsql_proxy" {
  metadata {
    name = "cloudsql-proxy"
  }
}

resource "kubernetes_secret_v1" "cloudsql_proxy_credentials" {
  metadata {
    name      = "cloudsql-proxy-credentials"
    namespace = kubernetes_namespace_v1.cloudsql_proxy.metadata[0].name
  }

  data = {
    "sa.json" = base64decode(var.cloudsql_proxy.sa_key)
  }
}

resource "helm_release" "cloudsql_proxy" {
  depends_on = [kubernetes_secret_v1.cloudsql_proxy_credentials]
  name       = "cloudsql-proxy"
  namespace  = kubernetes_namespace_v1.cloudsql_proxy.metadata[0].name
  repository = "oci://ghcr.io/prefeitura-rio/charts"
  chart      = "cloudsql-proxy"
  version    = "2.0.5"

  values = [yamlencode({
    instances = [
      {
        project         = "rj-iplanrio-dia"
        instance        = "postgres"
        serviceName     = "iplan"
        region          = "us-central1"
        port            = 5432
        listenPort      = 5432
        healthCheckPort = 9090
      },
      {
        project         = "rj-sme-danfe-ai"
        instance        = "mysql"
        serviceName     = "danfe"
        region          = "us-central1"
        port            = 3306
        listenPort      = 3306
        healthCheckPort = 9091
      }
    ]

    routing = {
      strategy = "multiservice"
    }

    proxy = {
      privateIp      = false
      autoIamAuthn   = false
      maxConnections = 150
    }

    secret = {
      existingSecret = kubernetes_secret_v1.cloudsql_proxy_credentials.metadata[0].name
      key            = "sa.json"
    }
  })]
}
