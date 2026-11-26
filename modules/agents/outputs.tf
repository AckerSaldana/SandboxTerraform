output "service_account" {
  description = "Cuenta de servicio de los agentes"
  value       = google_service_account.agents.email
}

output "service_uri" {
  description = "URL interna del agente (null si no se desplego)"
  value       = var.image == null ? null : google_cloud_run_v2_service.agent[0].uri
}
