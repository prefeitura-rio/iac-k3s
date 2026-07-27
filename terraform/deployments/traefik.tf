resource "kubectl_manifest" "traefik_config" {
  depends_on        = [helm_release.tailscale_operator]
  force_conflicts   = true
  server_side_apply = true

  yaml_body = yamlencode({
    apiVersion = "helm.cattle.io/v1"
    kind       = "HelmChartConfig"
    metadata = {
      name      = "traefik"
      namespace = "kube-system"
    }
    spec = {
      valuesContent = yamlencode({
        nodeSelector = { "kubernetes.io/hostname" = var.k3s_master.name }
        tolerations = [{
          key      = "node-role.kubernetes.io/control-plane"
          operator = "Exists"
          effect   = "NoSchedule"
        }]
        service = { type = "ClusterIP" }
        ports = {
          web       = { hostPort = 80 }
          websecure = { hostPort = 443 }
        }
      })
    }
  })
}
