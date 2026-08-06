resource "helm_release" "system_upgrade_controller" {
  name             = "system-upgrade-controller"
  repository       = "https://charts.rancher.io"
  chart            = "system-upgrade-controller"
  version          = "110.0.0"
  namespace        = "system-upgrade"
  create_namespace = true
}

resource "kubectl_manifest" "k3s_control_plane_plan" {
  depends_on = [helm_release.system_upgrade_controller]

  yaml_body = yamlencode({
    apiVersion = "upgrade.cattle.io/v1"
    kind       = "Plan"
    metadata = {
      name      = "k3s-control-plane"
      namespace = "system-upgrade"
    }
    spec = {
      concurrency        = 1
      cordon             = true
      serviceAccountName = "system-upgrade"
      nodeSelector = {
        matchExpressions = [{
          key      = "node-role.kubernetes.io/control-plane"
          operator = "In"
          values   = ["true"]
        }]
      }
      upgrade = {
        image = "rancher/k3s-upgrade"
      }
      channel = "https://update.k3s.io/v1-release/channels/v1.36"
    }
  })
}

resource "kubectl_manifest" "k3s_agent_plan" {
  depends_on = [kubectl_manifest.k3s_control_plane_plan]

  yaml_body = yamlencode({
    apiVersion = "upgrade.cattle.io/v1"
    kind       = "Plan"
    metadata = {
      name      = "k3s-agent"
      namespace = "system-upgrade"
    }
    spec = {
      concurrency        = 1
      cordon             = true
      serviceAccountName = "system-upgrade"
      nodeSelector = {
        matchExpressions = [{
          key      = "node-role.kubernetes.io/control-plane"
          operator = "DoesNotExist"
        }]
      }
      prepare = {
        image = "rancher/k3s-upgrade"
        args  = ["prepare", "k3s-control-plane"]
      }
      upgrade = {
        image = "rancher/k3s-upgrade"
      }
      channel = "https://update.k3s.io/v1-release/channels/v1.36"
    }
  })
}
