# Fabrica de sandboxes. Un archivo YAML por equipo produce un proyecto
# aislado con su subred, su presupuesto, sus permisos y sus etiquetas.

locals {
  team = var.team

  # Las etiquetas alimentan el reparto de costos por equipo
  labels = {
    team        = local.team.name
    owner       = substr(replace(lower(local.team.owner_group), "/[^a-z0-9_-]/", "-"), 0, 63)
    cost_center = local.team.cost_center
    expires     = local.team.expires
    profile     = local.team.profile
    size        = local.team.size
    managed_by  = "terraform"
  }

  # Cada sandbox toma un /16 del rango de sandboxes, segun su indice
  cidr = cidrsubnet(var.sandbox_range, 5, local.team.subnet_index)

  owners     = "group:${local.team.owner_group}"
  project_id = module.project.project_id
  number     = module.project.number

  needs_compute = local.team.workbench || anytrue([for g, n in local.team.gpu_quota : n > 0])
  wants_h100    = lookup(local.team.gpu_quota, "h100", 0) > 0
  reads_curated = contains(local.team.data_access, "curated")
}

module "project" {
  source          = "../project-factory"
  prefix          = var.prefix
  name            = local.team.name
  folder_id       = var.folder_id
  billing_account = var.billing_account
  labels          = local.labels
  services        = local.team.services
  shared_vpc_host = var.host_project
  deletion_policy = "DELETE"
}

# ---------------------------------------------------------------------
# Red y perimetro
# ---------------------------------------------------------------------
module "spoke" {
  source       = "../network-spoke"
  prefix       = var.prefix
  name         = local.team.name
  host_project = var.host_project
  network_id   = var.network_id
  region       = var.region
  cidr         = local.cidr

  users = {
    equipo = "serviceAccount:${google_service_account.team.email}"
  }
}

resource "google_access_context_manager_service_perimeter_resource" "enforced" {
  count          = var.perimeter_enforced ? 1 : 0
  perimeter_name = var.perimeter_name
  resource       = "projects/${local.number}"
}

resource "google_access_context_manager_service_perimeter_dry_run_resource" "dry_run" {
  count          = var.perimeter_enforced ? 0 : 1
  perimeter_name = var.perimeter_name
  resource       = "projects/${local.number}"
}

# ---------------------------------------------------------------------
# Identidad y permisos. El equipo usa la plataforma, pero no administra
# red, llaves ni permisos.
# ---------------------------------------------------------------------
resource "google_service_account" "team" {
  project      = local.project_id
  account_id   = "sa-${local.team.name}"
  display_name = "Cargas de trabajo del equipo ${local.team.name}"
}

resource "google_project_iam_member" "owners" {
  for_each = toset(local.team.roles)
  project  = local.project_id
  role     = each.key
  member   = local.owners
}

resource "google_project_iam_member" "team_sa" {
  for_each = toset(["roles/aiplatform.user", "roles/logging.logWriter", "roles/monitoring.metricWriter"])
  project  = local.project_id
  role     = each.key
  member   = "serviceAccount:${google_service_account.team.email}"
}

resource "google_service_account_iam_member" "owners_use_sa" {
  service_account_id = google_service_account.team.name
  role               = "roles/iam.serviceAccountUser"
  member             = local.owners
}

# Imagenes y paquetes: solo desde los repositorios internos
resource "google_project_iam_member" "registry_reader" {
  for_each = {
    equipo = "serviceAccount:${google_service_account.team.email}"
    lider  = local.owners
  }
  project = var.platform_project
  role    = "roles/artifactregistry.reader"
  member  = each.value
}

# Datos: unicamente la zona curated. La zona raw nunca se comparte.
resource "google_storage_bucket_iam_member" "curated" {
  for_each = local.reads_curated ? {
    equipo = "serviceAccount:${google_service_account.team.email}"
    lider  = local.owners
  } : {}
  bucket = var.curated_bucket
  role   = "roles/storage.objectViewer"
  member = each.value
}

resource "google_bigquery_dataset_iam_member" "curated" {
  for_each = local.reads_curated ? {
    equipo = "serviceAccount:${google_service_account.team.email}"
    lider  = local.owners
  } : {}
  project    = var.data_project
  dataset_id = var.curated_dataset
  role       = "roles/bigquery.dataViewer"
  member     = each.value
}

# ---------------------------------------------------------------------
# CMEK: los agentes de servicio del sandbox usan las llaves del cliente
# ---------------------------------------------------------------------
data "google_storage_project_service_account" "gcs" {
  project = local.project_id
}

data "google_bigquery_default_service_account" "bq" {
  project = local.project_id
}

locals {
  key_users = merge(
    {
      storage  = { key = "storage", member = "serviceAccount:${data.google_storage_project_service_account.gcs.email_address}" }
      bigquery = { key = "bigquery", member = "serviceAccount:${data.google_bigquery_default_service_account.bq.email}" }
    },
    local.needs_compute ? {
      compute = { key = "compute", member = "serviceAccount:service-${local.number}@compute-system.iam.gserviceaccount.com" }
    } : {}
  )
}

resource "google_kms_crypto_key_iam_member" "agents" {
  for_each      = local.key_users
  crypto_key_id = var.kms_keys[each.value.key]
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = each.value.member
}

# ---------------------------------------------------------------------
# Presupuesto: alertas al 50, 80 y 100 %. Al 100 % la funcion cost-guard
# detiene GPU, notebooks y endpoints del sandbox.
# ---------------------------------------------------------------------
resource "google_billing_budget" "this" {
  billing_account = var.billing_account
  display_name    = local.project_id

  budget_filter {
    projects        = ["projects/${local.number}"]
    calendar_period = "MONTH"
  }

  amount {
    specified_amount {
      currency_code = "USD"
      units         = tostring(local.team.monthly_budget_usd)
    }
  }

  dynamic "threshold_rules" {
    for_each = [0.5, 0.8, 1.0]
    content {
      threshold_percent = threshold_rules.value
    }
  }

  all_updates_rule {
    pubsub_topic   = var.budget_topic
    schema_version = "1.0"
  }
}

# ---------------------------------------------------------------------
# GPU: cuota por sandbox y excepcion de H100 solo con aprobacion
# ---------------------------------------------------------------------
resource "google_service_usage_consumer_quota_override" "gpu" {
  provider = google-beta
  for_each = var.enforce_gpu_quota ? { for g, n in local.team.gpu_quota : g => n if contains(keys(var.gpu_quota_metrics), g) } : {}

  project        = local.project_id
  service        = "compute.googleapis.com"
  metric         = urlencode(var.gpu_quota_metrics[each.key])
  limit          = urlencode("/project/region")
  override_value = tostring(each.value)
  force          = true

  dimensions = {
    region = var.region
  }
}

resource "google_org_policy_policy" "allow_h100" {
  count  = local.wants_h100 ? 1 : 0
  name   = "projects/${local.project_id}/policies/custom.aisbxSinH100"
  parent = "projects/${local.project_id}"

  spec {
    rules {
      enforce = "FALSE"
    }
  }
}

# ---------------------------------------------------------------------
# Notebook del equipo (segun el perfil)
# ---------------------------------------------------------------------
module "workbench" {
  count           = local.team.workbench ? 1 : 0
  source          = "../workbench"
  name            = "${var.prefix}-aisbx-${local.team.name}-nb"
  project_id      = local.project_id
  zone            = var.zone
  network_id      = var.network_id
  subnet_id       = module.spoke.subnet_id
  kms_key         = var.kms_keys["compute"]
  service_account = google_service_account.team.email
  idle_minutes    = var.workbench_idle_minutes
  labels          = local.labels

  depends_on = [google_kms_crypto_key_iam_member.agents]
}
