module "deployments" {
  count                       = var.kubeconfig_path != "" ? 1 : 0
  source                      = "./deployments"
  cloudsql_proxies            = var.cloudsql_proxies
  datametrica                 = var.datametrica
  github                      = var.github
  infisical                   = var.infisical
  jwks_mirror_public_hostname = var.jwks_mirror_public_hostname
  k3s_master                  = var.nodes.control_plane
  k3s_workers                 = var.nodes.workers
  prefect_address             = var.prefect_address
  tailscale                   = var.tailscale
}
