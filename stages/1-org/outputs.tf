output "folders" {
  description = "Carpetas creadas (formato folders/NUMERO)"
  value = {
    common     = google_folder.common.name
    ai_sandbox = google_folder.ai_sandbox.name
  }
}

output "projects" {
  description = "Proyectos comunes"
  value = {
    net_hub  = { id = module.net_hub.project_id, number = module.net_hub.number }
    logging  = { id = module.logging.project_id, number = module.logging.number }
    security = { id = module.security.project_id, number = module.security.number }
  }
}

output "labels" {
  description = "Etiquetas base de la plataforma"
  value       = local.labels
}
