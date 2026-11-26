output "index_id" {
  description = "Id del indice"
  value       = google_vertex_ai_index.this.id
}

output "index_endpoint_id" {
  description = "Id del endpoint del indice (null si no esta desplegado)"
  value       = var.deploy ? google_vertex_ai_index_endpoint.this[0].id : null
}
