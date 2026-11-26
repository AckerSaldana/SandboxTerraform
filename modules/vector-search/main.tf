# Vector Search para el piloto RAG. El indice no cuesta por si solo. El
# costo fijo aparece al desplegarlo en un endpoint, porque cobra por nodo
# aunque nadie consulte. Por eso el despliegue es opcional: los equipos
# pequenos pueden usar pgvector y solo el piloto despliega el indice.
resource "google_vertex_ai_index" "this" {
  display_name        = var.name
  project             = var.project_id
  region              = var.region
  labels              = var.labels
  index_update_method = "STREAM_UPDATE"

  metadata {
    contents_delta_uri = var.contents_uri

    config {
      dimensions                  = var.dimensions
      approximate_neighbors_count = 150
      distance_measure_type       = "DOT_PRODUCT_DISTANCE"
      shard_size                  = "SHARD_SIZE_SMALL"

      algorithm_config {
        tree_ah_config {
          leaf_node_embedding_count    = 1000
          leaf_nodes_to_search_percent = 10
        }
      }
    }
  }
}

resource "google_vertex_ai_index_endpoint" "this" {
  count        = var.deploy ? 1 : 0
  display_name = var.name
  project      = var.project_id
  region       = var.region
  labels       = var.labels

  private_service_connect_config {
    enable_private_service_connect = true
    project_allowlist              = var.project_allowlist
  }
}

resource "google_vertex_ai_index_endpoint_deployed_index" "this" {
  count             = var.deploy ? 1 : 0
  deployed_index_id = replace(var.name, "-", "_")
  index             = google_vertex_ai_index.this.id
  index_endpoint    = google_vertex_ai_index_endpoint.this[0].id
  region            = var.region

  dedicated_resources {
    min_replica_count = 1
    max_replica_count = var.max_replicas

    machine_spec {
      machine_type = var.machine_type
    }
  }
}
