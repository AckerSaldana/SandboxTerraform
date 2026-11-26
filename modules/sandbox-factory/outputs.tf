output "project_id" {
  description = "Proyecto del sandbox"
  value       = local.project_id
}

output "subnet_cidr" {
  description = "Bloque /16 del sandbox"
  value       = local.cidr
}

output "service_account" {
  description = "Cuenta de servicio del equipo"
  value       = google_service_account.team.email
}

output "monthly_budget_usd" {
  description = "Presupuesto mensual aplicado"
  value       = local.team.monthly_budget_usd
}

output "labels" {
  description = "Etiquetas del sandbox"
  value       = local.labels
}
