locals {
  nameserver_ip = try(data.kubernetes_resource.tailscale_dnsconfig.object.status.nameserver.ip, "100.100.100.100")
}

resource "kubernetes_namespace" "tailscale" {
  metadata {
    name = "tailscale"
  }
}

resource "helm_release" "tailscale_operator" {
  name       = "tailscale-operator"
  repository = "https://pkgs.tailscale.com/helmcharts"
  chart      = "tailscale-operator"
  namespace  = kubernetes_namespace.tailscale.metadata[0].name

  set = [
    {
      name  = "operatorConfig.hostname"
      value = "tailscale-operator-${var.tailscale.suffix}"
    },
    {
      name  = "oauth.clientId"
      value = var.tailscale.oauth.client_id
    },
    {
      name  = "oauth.clientSecret"
      value = var.tailscale.oauth.client_secret
    }
  ]
}

resource "kubectl_manifest" "tailscale_dnsconfig" {
  depends_on        = [helm_release.tailscale_operator]
  force_conflicts   = true
  server_side_apply = true
  yaml_body = yamlencode({
    apiVersion = "tailscale.com/v1alpha1"
    kind       = "DNSConfig"
    metadata = {
      name = "ts-dns"
    }
    spec = {
      nameserver = {
        image = {
          repo = "tailscale/k8s-nameserver"
          tag  = "unstable"
        }
      }
    }
  })
}

resource "kubectl_manifest" "tailscale_egress_proxyclass" {
  depends_on = [helm_release.tailscale_operator]
  yaml_body = yamlencode({
    apiVersion = "tailscale.com/v1alpha1"
    kind       = "ProxyClass"
    metadata = {
      name = "egress"
    }
    spec = {
      tailscale = {
        acceptRoutes = true
      }
    }
  })
}

resource "time_sleep" "wait_for_dnsconfig" {
  depends_on      = [kubectl_manifest.tailscale_dnsconfig]
  create_duration = "60s"
}

data "kubernetes_resource" "tailscale_dnsconfig" {
  api_version = "tailscale.com/v1alpha1"
  kind        = "DNSConfig"
  metadata {
    name = "ts-dns"
  }
  depends_on = [time_sleep.wait_for_dnsconfig]
}

resource "kubectl_manifest" "coredns_config" {
  depends_on = [data.kubernetes_resource.tailscale_dnsconfig]
  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "ConfigMap"
    metadata = {
      name      = "coredns"
      namespace = "kube-system"
    }
    data = {
      Corefile  = <<-EOF
        .:53 {
            errors
            health
            ready
            kubernetes cluster.local in-addr.arpa ip6.arpa {
              pods insecure
              fallthrough in-addr.arpa ip6.arpa
            }
            hosts /etc/coredns/NodeHosts {
              ttl 60
              reload 15s
              fallthrough
            }
            prometheus :9153
            forward . /etc/resolv.conf
            cache 30
            loop
            reload
            loadbalance
            import /etc/coredns/custom/*.override
        }
        ts.net {
            errors
            cache 30
            forward . ${local.nameserver_ip}
        }
        import /etc/coredns/custom/*.server
      EOF
      NodeHosts = <<-EOF
${var.k3s_master.ipv4_address} ${var.k3s_master.name}
%{for worker in var.k3s_workers~}
${worker.ipv4_address} ${worker.name}
%{endfor~}
EOF
    }
  })
}
