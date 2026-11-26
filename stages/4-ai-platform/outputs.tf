output "projects" {
  description = "Proyectos de IA y de datos"
  value = {
    ai_platform = { id = module.ai_platform.project_id, number = module.ai_platform.number }
    ai_data     = { id = module.ai_data.project_id, number = module.ai_data.number }
  }
}

output "curated" {
  description = "Zona curated, la unica visible a los sandboxes"
  value = {
    bucket  = module.data_lake.buckets["curated"]
    dataset = module.data_lake.datasets["curated"]
  }
}

output "registry" {
  description = "Repositorios internos"
  value = {
    docker = module.mlops.registry
    pypi   = module.mlops.pypi_url
  }
}

output "budget_topic" {
  description = "Tema de Pub/Sub de los presupuestos"
  value       = module.cost_guard.budget_topic
}

output "cost_views" {
  description = "Vistas de costo por equipo y por experimento"
  value       = module.cost_guard.cost_views
}

output "gke_cluster" {
  description = "Cluster compartido de GPU"
  value       = module.gke.cluster_name
}

output "model_armor_template" {
  description = "Plantilla de Model Armor"
  value       = module.ai_guardrails.model_armor_template
}

output "prompt_log_dataset" {
  description = "Dataset del registro de prompts"
  value       = module.ai_guardrails.prompt_log_dataset
}
