locals {
  infisical_auth_secret_name = "universal-auth-credentials"
}

resource "helm_release" "infisical_secrets_operator" {
  name             = "infisical-secrets-operator"
  repository       = "https://dl.cloudsmith.io/public/infisical/helm-charts/helm/charts/"
  chart            = "secrets-operator"
  namespace        = "infisical-operator-system"
  create_namespace = true
}

resource "kubernetes_config_map" "infisical_operator_global_settings" {
  metadata {
    name      = "infisical-config"
    namespace = helm_release.infisical_secrets_operator.namespace
  }

  data = {
    hostAPI = "${var.infisical.address}/api"
  }
}

resource "kubectl_manifest" "universal_auth_credentials" {
  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "Secret"
    metadata = {
      name      = local.infisical_auth_secret_name
      namespace = helm_release.infisical_secrets_operator.namespace
    }
    type = "Opaque"
    data = {
      clientId     = base64encode(var.infisical.client_id)
      clientSecret = base64encode(var.infisical.client_secret)
    }
  })
}
