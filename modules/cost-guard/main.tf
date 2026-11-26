# Control de costos.
#  1. Los presupuestos de cada sandbox publican en un tema de Pub/Sub.
#  2. Una funcion de Cloud Run detiene GPU, notebooks y endpoints del
#     sandbox cuando llega al 100 % de su presupuesto.
#  3. Vistas de BigQuery sobre la exportacion de facturacion muestran el
#     costo por equipo y por experimento (ver views.tf).

resource "google_pubsub_topic" "budgets" {
  name         = "${var.prefix}-aisbx-presupuestos"
  project      = var.project_id
  labels       = var.labels
  kms_key_name = var.pubsub_kms_key

  message_storage_policy {
    allowed_persistence_regions = [var.region]
  }
}

# Los presupuestos publican con esta cuenta administrada por Google
resource "google_pubsub_topic_iam_member" "budget_publisher" {
  project = var.project_id
  topic   = google_pubsub_topic.budgets.name
  role    = "roles/pubsub.publisher"
  member  = var.budget_publisher
}

resource "google_service_account" "function" {
  project      = var.project_id
  account_id   = "sa-cost-guard"
  display_name = "Apagado por presupuesto"
}

# La funcion actua sobre cualquier sandbox de la carpeta
resource "google_folder_iam_member" "function" {
  for_each = toset([
    "roles/compute.instanceAdmin.v1",
    "roles/notebooks.admin",
    "roles/aiplatform.user",
  ])
  folder = var.sandbox_folder
  role   = each.key
  member = "serviceAccount:${google_service_account.function.email}"
}

resource "google_project_iam_member" "function_invoker" {
  for_each = toset(["roles/run.invoker", "roles/eventarc.eventReceiver"])
  project  = var.project_id
  role     = each.key
  member   = "serviceAccount:${google_service_account.function.email}"
}

data "archive_file" "source" {
  type        = "zip"
  source_dir  = var.source_dir
  output_path = "${path.module}/.build/cost-guard.zip"
}

resource "google_storage_bucket" "source" {
  name                        = "${var.prefix}-aisbx-cost-guard-src"
  project                     = var.project_id
  location                    = var.region
  labels                      = var.labels
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = true

  encryption {
    default_kms_key_name = var.storage_kms_key
  }
}

resource "google_storage_bucket_object" "source" {
  name   = "cost-guard-${data.archive_file.source.output_md5}.zip"
  bucket = google_storage_bucket.source.name
  source = data.archive_file.source.output_path
}

# Con CMEK obligatorio, la funcion se construye en un repositorio propio
# cifrado con la llave del cliente.
resource "google_artifact_registry_repository" "functions" {
  project       = var.project_id
  location      = var.region
  repository_id = "funciones"
  description   = "Imagenes de las funciones de la plataforma"
  format        = "DOCKER"
  kms_key_name  = var.artifacts_kms_key
  labels        = var.labels
}

resource "google_cloudfunctions2_function" "guard" {
  name         = "${var.prefix}-aisbx-cost-guard"
  project      = var.project_id
  location     = var.region
  description  = "Detiene GPU, notebooks y endpoints al agotar el presupuesto"
  labels       = var.labels
  kms_key_name = var.artifacts_kms_key

  build_config {
    runtime           = "python312"
    entry_point       = "on_budget"
    docker_repository = google_artifact_registry_repository.functions.id

    source {
      storage_source {
        bucket = google_storage_bucket.source.name
        object = google_storage_bucket_object.source.name
      }
    }
  }

  service_config {
    available_memory      = "256M"
    timeout_seconds       = 300
    max_instance_count    = 2
    ingress_settings      = "ALLOW_INTERNAL_ONLY"
    service_account_email = google_service_account.function.email

    environment_variables = {
      REGION            = var.region
      STOP_AT_THRESHOLD = tostring(var.stop_at_threshold)
      DRY_RUN           = tostring(var.dry_run)
    }
  }

  event_trigger {
    trigger_region        = var.region
    event_type            = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic          = google_pubsub_topic.budgets.id
    retry_policy          = "RETRY_POLICY_DO_NOT_RETRY"
    service_account_email = google_service_account.function.email
  }
}
