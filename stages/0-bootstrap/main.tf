# Etapa 0-bootstrap. Es la unica que se aplica a mano, una sola vez.
# Crea el proyecto semilla, el bucket del estado de Terraform cifrado con
# llave propia, una cuenta de servicio por etapa y Workload Identity
# Federation para que GitHub Actions entre a Google Cloud sin llaves.

locals {
  stages = toset(["org", "security", "networks", "ai-platform", "sandboxes"])

  seed_apis = [
    "cloudresourcemanager.googleapis.com",
    "cloudbilling.googleapis.com",
    "billingbudgets.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
    "cloudkms.googleapis.com",
    "storage.googleapis.com",
    "serviceusage.googleapis.com",
    "orgpolicy.googleapis.com",
    "accesscontextmanager.googleapis.com",
    "privilegedaccessmanager.googleapis.com",
    "essentialcontacts.googleapis.com",
  ]

  labels = {
    team        = "plataforma"
    owner       = "plataforma"
    cost_center = var.cost_center
    expires     = "no-expira"
    managed_by  = "terraform"
  }

  # Roles de organizacion por etapa. Aqui solo va lo que no se puede dar
  # mas abajo en la jerarquia. Los permisos sobre carpetas y proyectos los
  # entrega la etapa que crea cada recurso (1-org, 2-security, 3-networks).
  org_roles = {
    org = [
      "roles/resourcemanager.folderAdmin",
      "roles/resourcemanager.projectCreator",
      "roles/orgpolicy.policyAdmin",
      "roles/logging.configWriter",
      "roles/privilegedaccessmanager.admin",
    ]
    security = [
      "roles/accesscontextmanager.policyAdmin",
      "roles/orgpolicy.policyAdmin",
      "roles/logging.configWriter",
    ]
    networks = [
      "roles/compute.xpnAdmin",
      "roles/compute.orgSecurityPolicyAdmin",
      "roles/compute.orgSecurityResourceAdmin",
    ]
    ai-platform = [
      "roles/orgpolicy.policyAdmin",
      "roles/accesscontextmanager.policyEditor",
    ]
    sandboxes = [
      "roles/accesscontextmanager.policyEditor",
      # Excepcion de H100 por proyecto, solo con aprobacion
      "roles/orgpolicy.policyAdmin",
    ]
  }

  org_bindings = merge([
    for stage, roles in local.org_roles : {
      for role in roles : "${stage}:${role}" => { stage = stage, role = role }
    }
  ]...)
}

# ---------------------------------------------------------------------
# Jerarquia: carpeta bootstrap y proyecto semilla
# ---------------------------------------------------------------------
resource "google_folder" "bootstrap" {
  display_name = "bootstrap"
  parent       = "organizations/${var.org_id}"
}

resource "google_project" "seed" {
  name                = "${var.prefix}-aisbx-seed"
  project_id          = "${var.prefix}-aisbx-seed"
  folder_id           = google_folder.bootstrap.folder_id
  billing_account     = var.billing_account
  labels              = local.labels
  auto_create_network = false
  deletion_policy     = "PREVENT"
}

resource "google_project_service" "seed" {
  for_each           = toset(local.seed_apis)
  project            = google_project.seed.project_id
  service            = each.key
  disable_on_destroy = false
}

# ---------------------------------------------------------------------
# CMEK para el estado de Terraform
# ---------------------------------------------------------------------
resource "google_kms_key_ring" "tfstate" {
  name     = "${var.prefix}-aisbx-tfstate"
  project  = google_project.seed.project_id
  location = var.region

  depends_on = [google_project_service.seed]
}

resource "google_kms_crypto_key" "tfstate" {
  name            = "tfstate"
  key_ring        = google_kms_key_ring.tfstate.id
  rotation_period = "7776000s" # 90 dias

  lifecycle {
    prevent_destroy = true
  }
}

# El agente de Cloud Storage debe poder usar la llave para cifrar el bucket
data "google_storage_project_service_account" "gcs" {
  project = google_project.seed.project_id

  depends_on = [google_project_service.seed]
}

resource "google_kms_crypto_key_iam_member" "gcs_agent" {
  crypto_key_id = google_kms_crypto_key.tfstate.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${data.google_storage_project_service_account.gcs.email_address}"
}

resource "google_storage_bucket" "tfstate" {
  name                        = "${var.prefix}-aisbx-tfstate"
  project                     = google_project.seed.project_id
  location                    = var.region
  labels                      = local.labels
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }

  encryption {
    default_kms_key_name = google_kms_crypto_key.tfstate.id
  }

  depends_on = [google_kms_crypto_key_iam_member.gcs_agent]
}

# ---------------------------------------------------------------------
# Una cuenta de servicio por etapa
# ---------------------------------------------------------------------
resource "google_service_account" "stage" {
  for_each     = local.stages
  project      = google_project.seed.project_id
  account_id   = "sa-tf-${each.key}"
  display_name = "Terraform pipeline (${each.key})"

  depends_on = [google_project_service.seed]
}

resource "google_storage_bucket_iam_member" "stage_state" {
  for_each = google_service_account.stage
  bucket   = google_storage_bucket.tfstate.name
  role     = "roles/storage.objectAdmin"
  member   = "serviceAccount:${each.value.email}"
}

resource "google_organization_iam_member" "stage" {
  for_each = local.org_bindings
  org_id   = var.org_id
  role     = each.value.role
  member   = "serviceAccount:${google_service_account.stage[each.value.stage].email}"
}

# Crear proyectos requiere poder asociarlos a la cuenta de facturacion
resource "google_billing_account_iam_member" "stage" {
  for_each           = toset(["org", "ai-platform", "sandboxes"])
  billing_account_id = var.billing_account
  role               = "roles/billing.user"
  member             = "serviceAccount:${google_service_account.stage[each.key].email}"
}

# Los presupuestos por sandbox los crea la etapa 5
resource "google_billing_account_iam_member" "budgets" {
  billing_account_id = var.billing_account
  role               = "roles/billing.costsManager"
  member             = "serviceAccount:${google_service_account.stage["sandboxes"].email}"
}

# ---------------------------------------------------------------------
# Workload Identity Federation: GitHub Actions entra sin llaves
# ---------------------------------------------------------------------
resource "google_iam_workload_identity_pool" "github" {
  project                   = google_project.seed.project_id
  workload_identity_pool_id = "github"
  display_name              = "GitHub Actions"

  depends_on = [google_project_service.seed]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = google_project.seed.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-actions"
  display_name                       = "GitHub Actions OIDC"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
  }

  # Solo el repositorio del proyecto puede usar este proveedor
  attribute_condition = "assertion.repository == \"${var.github_repo}\""

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account_iam_member" "wif" {
  for_each           = google_service_account.stage
  service_account_id = each.value.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repo}"
}
