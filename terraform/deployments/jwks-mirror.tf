resource "helm_release" "jwks_mirror" {
  name             = "jwks-mirror"
  repository       = "oci://registry-1.docker.io/cloudpirates"
  chart            = "nginx"
  version          = "0.16.1"
  namespace        = "jwks-mirror"
  create_namespace = true

  values = [yamlencode({
    fullnameOverride = "jwks-mirror"
    replicaCount     = 1

    containerPorts = [{
      name          = "http"
      containerPort = 8080
      protocol      = "TCP"
    }]

    service = {
      type = "ClusterIP"
      ports = [{
        port       = 8080
        targetPort = "http"
        protocol   = "TCP"
        name       = "http"
      }]
    }

    serverConfig = file("${path.module}/files/jwks-mirror-nginx.conf")

    livenessProbe = {
      enabled             = true
      type                = "httpGet"
      path                = "/healthz"
      initialDelaySeconds = 5
      periodSeconds       = 10
      timeoutSeconds      = 5
      failureThreshold    = 3
      successThreshold    = 1
    }

    readinessProbe = {
      enabled             = true
      type                = "httpGet"
      path                = "/healthz"
      initialDelaySeconds = 5
      periodSeconds       = 5
      timeoutSeconds      = 5
      failureThreshold    = 3
      successThreshold    = 1
    }

    resources = {
      requests = { cpu = "50m", memory = "32Mi" }
      limits   = { cpu = "200m", memory = "128Mi" }
    }

    extraVolumes = [
      { name = "cache", persistentVolumeClaim = { claimName = "jwks-mirror-cache" } },
      { name = "run", emptyDir = {} }
    ]

    extraVolumeMounts = [
      { name = "cache", mountPath = "/var/cache/nginx" },
      { name = "run", mountPath = "/var/run" }
    ]

    extraObjects = [{
      apiVersion = "v1"
      kind       = "PersistentVolumeClaim"
      metadata = {
        name      = "jwks-mirror-cache"
        namespace = "jwks-mirror"
      }
      spec = {
        accessModes      = ["ReadWriteOnce"]
        storageClassName = "local-path"
        resources        = { requests = { storage = "500Mi" } }
      }
    }]
  })]
}

resource "kubectl_manifest" "jwks_mirror_tailscale_ingress" {
  depends_on = [helm_release.tailscale_operator, helm_release.jwks_mirror]

  yaml_body = yamlencode({
    apiVersion = "networking.k8s.io/v1"
    kind       = "Ingress"

    metadata = {
      name      = "jwks-mirror"
      namespace = "jwks-mirror"
      annotations = {
        "tailscale.com/tags"     = "tag:k8s-${var.tailscale.suffix},tag:jwks-mirror"
        "tailscale.com/hostname" = "jwks-mirror"
      }
    }

    spec = {
      ingressClassName = "tailscale"
      defaultBackend = {
        service = {
          name = "jwks-mirror"
          port = { number = 8080 }
        }
      }
      tls = [{ hosts = ["jwks-mirror.${var.tailscale.domain}"] }]
    }
  })
}

resource "kubectl_manifest" "jwks_mirror_intranet_httproute" {
  depends_on = [kubectl_manifest.intranet_gateway, helm_release.jwks_mirror]

  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"

    metadata = {
      name      = "jwks-mirror-intranet"
      namespace = "jwks-mirror"
    }

    spec = {
      parentRefs = [{
        name        = "intranet"
        namespace   = helm_release.nginx_gateway_fabric.namespace
        sectionName = "https"
      }]
      hostnames = [var.jwks_mirror_public_hostname]
      rules = [{
        backendRefs = [{ name = "jwks-mirror", port = 8080 }]
      }]
    }
  })
}
