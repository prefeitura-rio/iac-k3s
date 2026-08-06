resource "helm_release" "gateway_api_crds" {
  name       = "gateway-api-crds"
  repository = "https://wiremind.github.io/wiremind-helm-charts"
  chart      = "gateway-api-crds"
  version    = "1.6.0"
  namespace  = "kube-system"
}

resource "helm_release" "nginx_gateway_fabric" {
  name             = "nginx-gateway-fabric"
  repository       = "oci://ghcr.io/nginx/charts"
  chart            = "nginx-gateway-fabric"
  version          = "2.6.7"
  namespace        = "nginx-gateway"
  create_namespace = true
  depends_on       = [helm_release.gateway_api_crds]

  values = [yamlencode({
    nginxGateway = {
      nodeSelector = { "kubernetes.io/hostname" = var.k3s.control_plane_hostname }
      tolerations = [{
        key      = "node-role.kubernetes.io/control-plane"
        operator = "Exists"
        effect   = "NoSchedule"
      }]
    }

    nginx = {
      service = { type = "ClusterIP" }
      pod = {
        nodeSelector = { "kubernetes.io/hostname" = var.k3s.control_plane_hostname }
        tolerations = [{
          key      = "node-role.kubernetes.io/control-plane"
          operator = "Exists"
          effect   = "NoSchedule"
        }]
      }
      container = {
        hostPorts = [
          { port = 80, containerPort = 80 },
          { port = 443, containerPort = 443 },
        ]
      }
    }
  })]
}

resource "kubectl_manifest" "intranet_gateway" {
  depends_on = [helm_release.nginx_gateway_fabric, kubectl_manifest.internal_ca_issuer]

  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "Gateway"
    metadata = {
      name      = "intranet"
      namespace = helm_release.nginx_gateway_fabric.namespace
      annotations = {
        "cert-manager.io/cluster-issuer" = "internal-ca-issuer"
      }
    }
    spec = {
      gatewayClassName = "nginx"
      listeners = [{
        name          = "https"
        port          = 443
        protocol      = "HTTPS"
        allowedRoutes = { namespaces = { from = "All" } }
        tls = {
          certificateRefs = [{
            name = "intranet-tls"
            kind = "Secret"
          }]
        }
      }]
    }
  })
}
