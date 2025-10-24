output "k3s_master_ip" {
  description = "IP address of the K3s master node"
  value       = incus_instance.k3s_master.ipv4_address
}

output "kubeconfig_path" {
  description = "Path to the kubeconfig file"
  value       = abspath("./files/kubeconfig")
}

output "dashboard_admin_token" {
  description = "Token for dashboard-admin service account"
  value       = length(module.deployments) > 0 ? module.deployments[0].dashboard_admin_token : null
  sensitive   = true
}
