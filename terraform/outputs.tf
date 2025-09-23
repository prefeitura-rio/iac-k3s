output "k3s_master_ip" {
  description = "IP address of the K3s master node"
  value       = incus_instance.k3s_master.ipv4_address
}

output "kubeconfig_path" {
  description = "Path to the kubeconfig file"
  value       = abspath("./kubeconfig")
  depends_on  = [null_resource.get_kubeconfig]
}

output "dashboard_admin_token" {
  description = "Token for dashboard-admin service account"
  value       = module.deployments.dashboard_admin_token
  sensitive   = true
}
