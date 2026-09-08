output "application_namespace" {
  description = "Namespace the application deploys into."
  value       = kubernetes_namespace_v1.app.metadata[0].name
}

output "installed_charts" {
  description = "Pinned platform chart versions actually installed."
  value = {
    aws_load_balancer_controller = var.lbc_chart_version
    secrets_store_csi_driver     = var.csi_driver_chart_version
    secrets_provider_aws         = var.aws_provider_chart_version
  }
}
