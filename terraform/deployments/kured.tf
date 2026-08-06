resource "helm_release" "kured" {
  name       = "kured"
  repository = "https://kubereboot.github.io/charts"
  chart      = "kured"
  version    = "6.1.0"
  namespace  = "kube-system"

  values = [yamlencode({
    configuration = {
      period         = "1h"
      drainTimeout   = "300s"
      concurrency    = 1
      rebootSentinel = "/var/run/reboot-required"
    }
    tolerations = [{
      key      = "node-role.kubernetes.io/control-plane"
      operator = "Exists"
      effect   = "NoSchedule"
    }]
    resources = {
      requests = { cpu = "50m", memory = "32Mi" }
      limits   = { cpu = "100m", memory = "64Mi" }
    }
  })]
}
