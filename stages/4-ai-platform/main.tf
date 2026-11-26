# Etapa 4-ai-platform: proyectos de IA y de datos, lago con anonimizacion,
# computo acelerado, servicios de IA, guardrails, cadena de suministro
# segura y control de costos.

data "terraform_remote_state" "bootstrap" {
  backend = "gcs"
  config = {
    bucket = var.tfstate_bucket
    prefix = "0-bootstrap"
  }
}

data "terraform_remote_state" "org" {
  backend = "gcs"
  config = {
    bucket = var.tfstate_bucket
    prefix = "1-org"
  }
}

data "terraform_remote_state" "security" {
  backend = "gcs"
  config = {
    bucket = var.tfstate_bucket
    prefix = "2-security"
  }
}

data "terraform_remote_state" "networks" {
  backend = "gcs"
  config = {
    bucket = var.tfstate_bucket
    prefix = "3-networks"
  }
}

locals {
  org      = data.terraform_remote_state.org.outputs
  security = data.terraform_remote_state.security.outputs
  net      = data.terraform_remote_state.networks.outputs

  folder = local.org.folders.ai_sandbox
  keys   = local.security.kms_keys
  labels = local.org.labels

  platform = module.ai_platform.project_id
  data     = module.ai_data.project_id
}

# ---------------------------------------------------------------------
# Proyectos
# ---------------------------------------------------------------------
module "ai_platform" {
  source          = "../../modules/project-factory"
  prefix          = var.prefix
  name            = "ai-platform"
  folder_id       = local.folder
  billing_account = var.billing_account
  labels          = local.labels
  shared_vpc_host = local.net.host_project
  services = [
    "aiplatform.googleapis.com",
    "artifactregistry.googleapis.com",
    "binaryauthorization.googleapis.com",
    "bigquery.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudfunctions.googleapis.com",
    "compute.googleapis.com",
    "container.googleapis.com",
    "containerscanning.googleapis.com",
    "eventarc.googleapis.com",
    "modelarmor.googleapis.com",
    "notebooks.googleapis.com",
    "pubsub.googleapis.com",
    "run.googleapis.com",
    "storage.googleapis.com",
  ]
}

module "ai_data" {
  source          = "../../modules/project-factory"
  prefix          = var.prefix
  name            = "ai-data"
  folder_id       = local.folder
  billing_account = var.billing_account
  labels          = local.labels
  shared_vpc_host = local.net.host_project
  services = [
    "bigquery.googleapis.com",
    "dataflow.googleapis.com",
    "dlp.googleapis.com",
    "storage.googleapis.com",
  ]
}

# Los dos proyectos entran al perimetro. Se usa el recurso que corresponde
# al modo actual: de prueba u obligatorio.
locals {
  perimeter_projects = {
    ai-platform = module.ai_platform.number
    ai-data     = module.ai_data.number
  }
}

resource "google_access_context_manager_service_perimeter_resource" "enforced" {
  for_each       = local.security.perimeter_enforced ? local.perimeter_projects : {}
  perimeter_name = local.security.perimeter_name
  resource       = "projects/${each.value}"
}

resource "google_access_context_manager_service_perimeter_dry_run_resource" "dry_run" {
  for_each       = local.security.perimeter_enforced ? {} : local.perimeter_projects
  perimeter_name = local.security.perimeter_name
  resource       = "projects/${each.value}"
}

# ---------------------------------------------------------------------
# Agentes de servicio y uso de llaves (CMEK)
# ---------------------------------------------------------------------
resource "google_project_service_identity" "platform" {
  provider = google-beta
  for_each = toset([
    "aiplatform.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudfunctions.googleapis.com",
    "container.googleapis.com",
    "pubsub.googleapis.com",
    "run.googleapis.com",
  ])
  project = local.platform
  service = each.key
}

resource "google_project_service_identity" "dlp" {
  provider = google-beta
  project  = local.data
  service  = "dlp.googleapis.com"
}

data "google_storage_project_service_account" "gcs" {
  for_each = { platform = local.platform, data = local.data }
  project  = each.value
}

data "google_bigquery_default_service_account" "bq" {
  for_each = { platform = local.platform, data = local.data }
  project  = each.value
}

locals {
  agents = { for k, v in google_project_service_identity.platform : k => v.member }

  key_users = {
    storage-platform  = { key = "storage", member = "serviceAccount:${data.google_storage_project_service_account.gcs["platform"].email_address}" }
    storage-data      = { key = "storage", member = "serviceAccount:${data.google_storage_project_service_account.gcs["data"].email_address}" }
    bigquery-platform = { key = "bigquery", member = "serviceAccount:${data.google_bigquery_default_service_account.bq["platform"].email}" }
    bigquery-data     = { key = "bigquery", member = "serviceAccount:${data.google_bigquery_default_service_account.bq["data"].email}" }
    vertex            = { key = "vertex", member = local.agents["aiplatform.googleapis.com"] }
    artifacts         = { key = "artifacts", member = local.agents["artifactregistry.googleapis.com"] }
    artifacts-gcf     = { key = "artifacts", member = local.agents["cloudfunctions.googleapis.com"] }
    artifacts-run     = { key = "artifacts", member = local.agents["run.googleapis.com"] }
    artifacts-gcs     = { key = "artifacts", member = "serviceAccount:${data.google_storage_project_service_account.gcs["platform"].email_address}" }
    pubsub            = { key = "pubsub", member = local.agents["pubsub.googleapis.com"] }
    compute           = { key = "compute", member = "serviceAccount:service-${module.ai_platform.number}@compute-system.iam.gserviceaccount.com" }
    compute-gke       = { key = "compute", member = local.agents["container.googleapis.com"] }
  }
}

resource "google_kms_crypto_key_iam_member" "agents" {
  for_each      = local.key_users
  crypto_key_id = local.keys[each.value.key]
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = each.value.member
}

# ---------------------------------------------------------------------
# Datos: lago raw/curated y anonimizacion
# ---------------------------------------------------------------------
module "data_lake" {
  source           = "../../modules/data-lake"
  prefix           = var.prefix
  project_id       = local.data
  region           = var.region
  storage_kms_key  = local.keys["storage"]
  bigquery_kms_key = local.keys["bigquery"]
  force_destroy    = var.force_destroy
  labels           = local.labels

  depends_on = [google_kms_crypto_key_iam_member.agents]
}

module "dlp_pipeline" {
  source           = "../../modules/dlp-pipeline"
  project_id       = local.data
  region           = var.region
  raw_bucket       = module.data_lake.buckets["raw"]
  curated_bucket   = module.data_lake.buckets["curated"]
  dlp_agent        = google_project_service_identity.dlp.member
  bigquery_kms_key = local.keys["bigquery"]
  labels           = local.labels
}

# ---------------------------------------------------------------------
# MLOps y cadena de suministro segura
# ---------------------------------------------------------------------
module "mlops" {
  source            = "../../modules/mlops"
  prefix            = var.prefix
  project_id        = local.platform
  region            = var.region
  kms_key           = local.keys["artifacts"]
  storage_kms_key   = local.keys["storage"]
  binauthz_enforced = var.binauthz_enforced
  force_destroy     = var.force_destroy
  labels            = local.labels

  readers = {
    nodos = "serviceAccount:${google_service_account.gke_nodes.email}"
  }

  depends_on = [google_kms_crypto_key_iam_member.agents]
}

# ---------------------------------------------------------------------
# Computo acelerado: GKE con GPU y TPU
# ---------------------------------------------------------------------
resource "google_service_account" "gke_nodes" {
  project      = local.platform
  account_id   = "sa-gke-nodos"
  display_name = "Nodos de GKE"
}

resource "google_project_iam_member" "gke_nodes" {
  for_each = toset(["roles/logging.logWriter", "roles/monitoring.metricWriter", "roles/monitoring.viewer"])
  project  = local.platform
  role     = each.key
  member   = "serviceAccount:${google_service_account.gke_nodes.email}"
}

# En una Shared VPC, los agentes de GKE necesitan usar la subred del anfitrion
resource "google_project_iam_member" "gke_host_agent" {
  project = local.net.host_project
  role    = "roles/container.hostServiceAgentUser"
  member  = local.agents["container.googleapis.com"]
}

resource "google_compute_subnetwork_iam_member" "gke" {
  for_each = {
    gke           = local.agents["container.googleapis.com"]
    cloudservices = "serviceAccount:${module.ai_platform.number}@cloudservices.gserviceaccount.com"
  }
  project    = local.net.host_project
  region     = var.region
  subnetwork = local.net.subnet_names["ai-platform"]
  role       = "roles/compute.networkUser"
  member     = each.value
}

module "gke" {
  source               = "../../modules/gke-gpu"
  name                 = "${var.prefix}-aisbx-gpu"
  project_id           = local.platform
  region               = var.region
  network_id           = local.net.network_id
  subnet_id            = local.net.subnet_ids["ai-platform"]
  pods_range           = "pods"
  services_range       = "services"
  kms_key              = local.keys["compute"]
  node_service_account = google_service_account.gke_nodes.email
  binary_authorization = true
  gpu_node_pools       = var.gpu_node_pools
  deletion_protection  = !var.force_destroy
  labels               = local.labels

  depends_on = [
    google_kms_crypto_key_iam_member.agents,
    google_project_iam_member.gke_host_agent,
    google_compute_subnetwork_iam_member.gke,
    module.mlops,
  ]
}

module "tpu" {
  count                = var.enable_tpu ? 1 : 0
  source               = "../../modules/tpu"
  project_id           = local.platform
  region               = var.region
  cluster_name         = module.gke.cluster_name
  zones                = var.tpu_zones
  kms_key              = local.keys["compute"]
  node_service_account = google_service_account.gke_nodes.email
  labels               = local.labels
}

# ---------------------------------------------------------------------
# Servicios de IA
# ---------------------------------------------------------------------
module "vertex_models" {
  source         = "../../modules/vertex-models"
  parent         = local.folder
  allowed_models = var.allowed_models
}

module "vertex_training" {
  source        = "../../modules/vertex-training"
  prefix        = var.prefix
  project_id    = local.platform
  region        = var.region
  kms_key       = local.keys["storage"]
  force_destroy = var.force_destroy
  labels        = local.labels

  depends_on = [google_kms_crypto_key_iam_member.agents]
}

module "ai_guardrails" {
  source           = "../../modules/ai-guardrails"
  prefix           = var.prefix
  project_id       = local.platform
  region           = var.region
  bigquery_kms_key = local.keys["bigquery"]
  retention_days   = var.prompt_log_retention_days
  force_destroy    = var.force_destroy
  labels           = local.labels

  depends_on = [google_kms_crypto_key_iam_member.agents]
}

# Endpoint privado para modelos abiertos, por Private Service Connect
module "vertex_endpoints" {
  source             = "../../modules/vertex-endpoints"
  endpoint_id        = "1001"
  display_name       = "${var.prefix}-aisbx-modelos-abiertos"
  project_id         = local.platform
  region             = var.region
  kms_key            = local.keys["vertex"]
  project_allowlist  = [local.platform]
  prompt_log_dataset = module.ai_guardrails.prompt_log_dataset
  service_attachment = var.endpoint_service_attachment
  network_project    = local.net.host_project
  network_id         = local.net.network_id
  psc_address        = local.net.vertex_psc_address
  labels             = local.labels

  depends_on = [google_kms_crypto_key_iam_member.agents]
}

module "vector_search" {
  count             = var.enable_vector_search ? 1 : 0
  source            = "../../modules/vector-search"
  name              = "${var.prefix}-aisbx-rag"
  project_id        = local.platform
  region            = var.region
  contents_uri      = "gs://${module.mlops.pipelines_bucket}/rag/embeddings"
  deploy            = var.deploy_vector_index
  project_allowlist = [local.platform]
  labels            = local.labels
}

module "agents" {
  source     = "../../modules/agents"
  project_id = local.platform
  region     = var.region
  kms_key    = local.keys["artifacts"]
  network_id = local.net.network_id
  subnet_id  = local.net.subnet_ids["ai-platform"]
  image      = var.agent_image
  labels     = local.labels
}

# ---------------------------------------------------------------------
# Control de costos
# ---------------------------------------------------------------------
module "cost_guard" {
  source               = "../../modules/cost-guard"
  prefix               = var.prefix
  project_id           = local.platform
  region               = var.region
  sandbox_folder       = local.folder
  source_dir           = "${path.module}/../../functions/cost-guard"
  artifacts_kms_key    = local.keys["artifacts"]
  storage_kms_key      = local.keys["storage"]
  pubsub_kms_key       = local.keys["pubsub"]
  dry_run              = var.cost_guard_dry_run
  billing_export_table = var.billing_export_table
  views_project        = local.org.projects.logging.id
  views_location       = var.region
  views_kms_key        = local.keys["bigquery"]
  labels               = local.labels

  depends_on = [google_kms_crypto_key_iam_member.agents]
}

# ---------------------------------------------------------------------
# Permisos de la etapa 5-sandboxes sobre los recursos compartidos. Los
# necesita para dar a cada equipo lectura de imagenes y de la zona curated
# y para conectar su presupuesto al tema de Pub/Sub.
# ---------------------------------------------------------------------
locals {
  sandboxes_sa = "serviceAccount:${data.terraform_remote_state.bootstrap.outputs.stage_service_accounts["sandboxes"]}"

  sandboxes_roles = {
    "platform:roles/resourcemanager.projectIamAdmin" = local.platform
    "platform:roles/pubsub.admin"                    = local.platform
    "data:roles/storage.admin"                       = local.data
    "data:roles/bigquery.dataOwner"                  = local.data
  }
}

resource "google_project_iam_member" "sandboxes_stage" {
  for_each = local.sandboxes_roles
  project  = each.value
  role     = split(":", each.key)[1]
  member   = local.sandboxes_sa
}
