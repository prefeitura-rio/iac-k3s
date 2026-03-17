locals {
  cloudsql_proxy_keys = keys(var.cloudsql_proxies)
}

resource "kubernetes_namespace_v1" "cloudsql_proxy" {
  metadata {
    name = "cloudsql-proxy"
  }
}

resource "kubernetes_config_map_v1" "cloudsql_proxy" {
  for_each = var.cloudsql_proxies

  metadata {
    name      = "${each.key}-config"
    namespace = kubernetes_namespace_v1.cloudsql_proxy.metadata[0].name
  }
  data = {
    CLOUD_SQL_PROJECT_ID      = each.value.project_id
    CLOUD_SQL_INSTANCE_REGION = each.value.instance_region
    CLOUD_SQL_INSTANCE_NAME   = each.value.instance_name
  }
}

resource "kubernetes_secret_v1" "cloudsql_proxy" {
  for_each = var.cloudsql_proxies

  metadata {
    name      = "${each.key}-sa-key"
    namespace = kubernetes_namespace_v1.cloudsql_proxy.metadata[0].name
  }

  data = {
    "service-account-key.json" = base64decode(each.value.sa_key)
  }
}


resource "helm_release" "cloudsql_proxy" {
  for_each   = var.cloudsql_proxies
  depends_on = [kubernetes_config_map_v1.cloudsql_proxy, kubernetes_secret_v1.cloudsql_proxy]
  name       = each.key
  namespace  = kubernetes_namespace_v1.cloudsql_proxy.metadata[0].name
  repository = "https://prefeitura-rio.github.io/charts"
  chart      = "cloudsql-proxy"
  version    = "1.0.1"

  values = [yamlencode({
    fullnameOverride = each.key

    instance = {
      configMapRef = {
        name = kubernetes_config_map_v1.cloudsql_proxy[each.key].metadata[0].name
        keys = {
          projectId = "CLOUD_SQL_PROJECT_ID"
          region    = "CLOUD_SQL_INSTANCE_REGION"
          name      = "CLOUD_SQL_INSTANCE_NAME"
        }
      }
    }

    secret = {
      existingSecret = kubernetes_secret_v1.cloudsql_proxy[each.key].metadata[0].name
    }

    proxy = {
      port            = tonumber(each.value.port)
      privateIp       = each.value.private
      autoIamAuthn    = false
      maxConnections  = 100
      healthCheckPort = 9090 + index(local.cloudsql_proxy_keys, each.key)
    }

    resources = {
      requests = {
        cpu    = "100m"
        memory = "128Mi"
      }
      limits = {
        cpu    = "500m"
        memory = "256Mi"
      }
    }
  })]

}
