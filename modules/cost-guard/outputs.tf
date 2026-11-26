output "budget_topic" {
  description = "Tema de Pub/Sub donde publican los presupuestos"
  value       = google_pubsub_topic.budgets.id
}

output "function_service_account" {
  description = "Cuenta de servicio de la funcion de apagado"
  value       = google_service_account.function.email
}

output "cost_views" {
  description = "Vistas de costo (vacio si no hay exportacion de facturacion)"
  value = local.views_enabled ? {
    por_equipo      = "${var.views_project}.costos.${google_bigquery_table.by_team[0].table_id}"
    por_experimento = "${var.views_project}.costos.${google_bigquery_table.by_experiment[0].table_id}"
    sin_experimento = "${var.views_project}.costos.${google_bigquery_table.untagged[0].table_id}"
  } : {}
}
