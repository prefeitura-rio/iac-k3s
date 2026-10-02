locals {
  ghcr_namespaces = toset(concat(
    [
      "suptm",
      "suptm-staging",
    ],
  ))

  dockerconfigjson = jsonencode({
    auths = {
      "ghcr.io" = {
        username = var.github.username
        password = var.github.password
        auth     = base64encode("${var.github.username}:${var.github.password}")
      }
    }
  })
}

resource "kubernetes_secret_v1" "fluxcd_git_auth" {
  for_each = local.ghcr_namespaces

  metadata {
    name      = "flux-git-auth"
    namespace = each.key
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    username            = var.github.username
    password            = var.github.password
    ".dockerconfigjson" = local.dockerconfigjson
  }
}

resource "kubernetes_secret_v1" "ghcr_credentials" {
  for_each = local.ghcr_namespaces
  depends_on = [
    kubernetes_namespace_v1.flux_cd,
  ]

  metadata {
    name      = "ghcr-credentials"
    namespace = each.value
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = local.dockerconfigjson
  }
}
