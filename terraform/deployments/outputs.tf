output "dashboard_admin_token" {
  description = "Token for dashboard-admin service account"
  value       = kubernetes_secret.dashboard_admin_token.data["token"]
  sensitive   = true
}

