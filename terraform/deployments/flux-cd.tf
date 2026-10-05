resource "kubernetes_namespace_v1" "flux_cd" {
  metadata {
    name = "flux-system"

    annotations = {
      "fluxcd.controlplane.io/prune"      = "disabled"
      "kustomize.toolkit.fluxcd.io/prune" = "Disabled"
      "kustomize.toolkit.fluxcd.io/ssa"   = "Ignore"
    }

    labels = {
      "app.kubernetes.io/instance"       = "flux-system"
      "app.kubernetes.io/managed-by"     = "flux-operator"
      "app.kubernetes.io/part-of"        = "flux"
      "app.kubernetes.io/version"        = "v2.9.6"
      "fluxcd.controlplane.io/name"      = "flux"
      "fluxcd.controlplane.io/namespace" = "flux-system"
    }
  }
}

resource "kubernetes_secret_v1" "flux_git_auth" {
  depends_on = [kubernetes_namespace_v1.flux_cd]

  metadata {
    name      = "flux-git-auth"
    namespace = "flux-system"
  }

  type = "Opaque"

  data = {
    username = var.github.username
    password = var.github.password
  }
}

resource "helm_release" "flux_operator" {
  depends_on = [kubernetes_namespace_v1.flux_cd]

  name             = "flux-operator"
  repository       = "oci://ghcr.io/controlplaneio-fluxcd/charts"
  chart            = "flux-operator"
  version          = "0.56.0"
  namespace        = "flux-system"
  create_namespace = false
  wait             = true
  cleanup_on_fail  = true
}

resource "helm_release" "flux_instance" {
  depends_on = [helm_release.flux_operator]

  name       = "flux-instance"
  repository = "oci://ghcr.io/controlplaneio-fluxcd/charts"
  chart      = "flux-instance"
  namespace  = "flux-system"

  values = [
    yamlencode({
      instance = {
        distribution = {
          version  = "2.x"
          registry = "ghcr.io/fluxcd"
        }

        components = [
          "source-controller",
          "kustomize-controller",
          "helm-controller",
          "image-reflector-controller",
          "image-automation-controller",
          "notification-controller"
        ]
      }
    })
  ]
}
