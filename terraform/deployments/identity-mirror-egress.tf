resource "kubectl_manifest" "airbyte_identity_mirror_egress_service" {
  depends_on = [kubectl_manifest.tailscale_egress_proxyclass]

  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "Service"
    metadata = {
      name      = "identity-mirror-cloudsql-proxy"
      namespace = "airbyte"
      annotations = {
        "tailscale.com/proxy-class" = "egress"
        "tailscale.com/tags"        = "tag:k8s-${var.tailscale.suffix},tag:identity-mirror-client"
        "tailscale.com/tailnet-ip"  = "100.84.37.36"
      }
    }
    spec = {
      type         = "ExternalName"
      externalName = "placeholder"
    }
  })
}

resource "kubectl_manifest" "airbyte_identity_mirror_prod_egress_service" {
  depends_on = [kubectl_manifest.tailscale_egress_proxyclass]

  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "Service"
    metadata = {
      name      = "identity-mirror-prod-cloudsql-proxy"
      namespace = "airbyte"
      annotations = {
        "tailscale.com/proxy-class" = "egress"
        "tailscale.com/tags"        = "tag:k8s-${var.tailscale.suffix},tag:identity-mirror-client"
        "tailscale.com/tailnet-ip"  = "100.69.161.115"
      }
    }
    spec = {
      type         = "ExternalName"
      externalName = "placeholder"
    }
  })
}
