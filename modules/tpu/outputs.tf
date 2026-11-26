output "node_pool" {
  description = "Nombre del node pool de TPU"
  value       = google_container_node_pool.tpu.name
}
