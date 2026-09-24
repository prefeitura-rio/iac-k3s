module "deployments" {
  count                       = var.kubeconfig_path != "" ? 1 : 0
  source                      = "./deployments"
  airbyte                     = var.airbyte
  cloudsql_proxy              = var.cloudsql_proxy
  datametrica                 = var.datametrica
  github                      = var.github
  infisical                   = var.infisical
  jwks_mirror_public_hostname = var.jwks_mirror_public_hostname
  k3s                         = var.k3s
  prefect_address             = var.prefect_address
  tailscale                   = var.tailscale
}
