# MLOps y cadena de suministro segura.
#  1. Repositorios remotos: espejo interno de PyPI y Docker Hub. Casi nada
#     necesita salir a Internet y las descargas quedan en cache.
#  2. Escaneo de vulnerabilidades: Artifact Analysis revisa cada imagen la
#     primera vez que se sube.
#  3. Binary Authorization: en GKE solo corren imagenes del repositorio
#     interno. Primero en modo de prueba y despues obligatorio.

locals {
  registry = "${var.region}-docker.pkg.dev/${var.project_id}"
}

resource "google_artifact_registry_repository" "images" {
  project       = var.project_id
  location      = var.region
  repository_id = "imagenes"
  description   = "Imagenes de contenedor de la plataforma y de los equipos"
  format        = "DOCKER"
  kms_key_name  = var.kms_key
  labels        = var.labels

  docker_config {
    immutable_tags = true
  }

  vulnerability_scanning_config {
    enablement_config = "INHERITED"
  }
}

resource "google_artifact_registry_repository" "python" {
  project       = var.project_id
  location      = var.region
  repository_id = "paquetes"
  description   = "Paquetes de Python internos"
  format        = "PYTHON"
  kms_key_name  = var.kms_key
  labels        = var.labels
}

resource "google_artifact_registry_repository" "pypi_remote" {
  project       = var.project_id
  location      = var.region
  repository_id = "pypi-remoto"
  description   = "Espejo de PyPI"
  format        = "PYTHON"
  mode          = "REMOTE_REPOSITORY"
  kms_key_name  = var.kms_key
  labels        = var.labels

  remote_repository_config {
    description = "PyPI"
    python_repository {
      public_repository = "PYPI"
    }
  }
}

resource "google_artifact_registry_repository" "dockerhub_remote" {
  project       = var.project_id
  location      = var.region
  repository_id = "dockerhub-remoto"
  description   = "Espejo de Docker Hub"
  format        = "DOCKER"
  mode          = "REMOTE_REPOSITORY"
  kms_key_name  = var.kms_key
  labels        = var.labels

  remote_repository_config {
    description = "Docker Hub"
    docker_repository {
      public_repository = "DOCKER_HUB"
    }
  }

  vulnerability_scanning_config {
    enablement_config = "INHERITED"
  }
}

resource "google_artifact_registry_repository_iam_member" "reader" {
  for_each = {
    for pair in setproduct(["imagenes", "paquetes", "pypi-remoto", "dockerhub-remoto"], keys(var.readers)) :
    "${pair[0]}:${pair[1]}" => { repo = pair[0], member = var.readers[pair[1]] }
  }
  project    = var.project_id
  location   = var.region
  repository = each.value.repo
  role       = "roles/artifactregistry.reader"
  member     = each.value.member

  depends_on = [
    google_artifact_registry_repository.images,
    google_artifact_registry_repository.python,
    google_artifact_registry_repository.pypi_remote,
    google_artifact_registry_repository.dockerhub_remote,
  ]
}

# ---------------------------------------------------------------------
# Binary Authorization
# ---------------------------------------------------------------------
resource "google_binary_authorization_policy" "this" {
  project = var.project_id

  # Permite las imagenes de sistema que mantiene Google (GKE, controladores de GPU)
  global_policy_evaluation_mode = "ENABLE"

  default_admission_rule {
    evaluation_mode  = "ALWAYS_DENY"
    enforcement_mode = var.binauthz_enforced ? "ENFORCED_BLOCK_AND_AUDIT_LOG" : "DRYRUN_AUDIT_LOG_ONLY"
  }

  dynamic "admission_whitelist_patterns" {
    for_each = concat(["${local.registry}/imagenes/**"], var.extra_allowed_images)
    content {
      name_pattern = admission_whitelist_patterns.value
    }
  }
}

# ---------------------------------------------------------------------
# Vertex AI Pipelines
# ---------------------------------------------------------------------
resource "google_service_account" "pipelines" {
  project      = var.project_id
  account_id   = "sa-pipelines"
  display_name = "Vertex AI Pipelines"
}

resource "google_project_iam_member" "pipelines" {
  for_each = toset(["roles/aiplatform.user", "roles/artifactregistry.reader", "roles/logging.logWriter"])
  project  = var.project_id
  role     = each.key
  member   = "serviceAccount:${google_service_account.pipelines.email}"
}

resource "google_storage_bucket" "pipelines" {
  name                        = "${var.prefix}-aisbx-pipelines"
  project                     = var.project_id
  location                    = var.region
  labels                      = var.labels
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = var.force_destroy

  encryption {
    default_kms_key_name = var.storage_kms_key
  }
}

resource "google_storage_bucket_iam_member" "pipelines" {
  bucket = google_storage_bucket.pipelines.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.pipelines.email}"
}
