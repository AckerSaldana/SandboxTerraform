# Etapa 5-sandboxes: un sandbox por cada archivo en teams/. El catalogo
# profiles.yaml convierte perfil y talla en servicios, permisos,
# presupuesto y cuota de GPU.

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

data "terraform_remote_state" "ai" {
  backend = "gcs"
  config = {
    bucket = var.tfstate_bucket
    prefix = "4-ai-platform"
  }
}

locals {
  org      = data.terraform_remote_state.org.outputs
  security = data.terraform_remote_state.security.outputs
  net      = data.terraform_remote_state.networks.outputs
  ai       = data.terraform_remote_state.ai.outputs

  catalog = yamldecode(file("${path.module}/profiles.yaml"))

  requests = {
    for f in fileset("${path.module}/teams", "*.yaml") :
    trimsuffix(f, ".yaml") => yamldecode(file("${path.module}/teams/${f}"))
  }

  # Solicitud + perfil + talla = sandbox resuelto
  teams = {
    for file, t in local.requests : file => {
      name         = t.name
      owner_group  = t.owner_group
      cost_center  = t.cost_center
      expires      = t.expires
      profile      = t.profile
      size         = t.size
      subnet_index = t.subnet_index

      monthly_budget_usd = try(t.monthly_budget_usd, local.catalog.profiles[t.profile].sizes[t.size].monthly_budget_usd)
      gpu_quota          = try(t.gpu_quota, local.catalog.profiles[t.profile].sizes[t.size].gpu_quota)

      services    = distinct(concat(local.catalog.base.services, local.catalog.profiles[t.profile].services))
      roles       = distinct(concat(local.catalog.base.roles, local.catalog.profiles[t.profile].roles))
      data_access = local.catalog.profiles[t.profile].data_access
      workbench   = local.catalog.profiles[t.profile].workbench
    }
  }

  indexes = [for t in local.requests : t.subnet_index]
}

# Reglas que dependen de todas las solicitudes a la vez. Las mismas reglas
# corren antes, en el pull request, con conftest (policies/sandbox).
resource "terraform_data" "reglas" {
  lifecycle {
    precondition {
      condition     = length(local.indexes) == length(distinct(local.indexes))
      error_message = "Dos equipos comparten subnet_index. Cada sandbox necesita un indice unico."
    }
    precondition {
      condition     = alltrue([for file, t in local.requests : file == t.name])
      error_message = "El nombre del archivo debe coincidir con el campo name."
    }
    precondition {
      condition     = alltrue([for t in local.teams : t.monthly_budget_usd <= local.catalog.limits.max_monthly_budget_usd])
      error_message = "Un sandbox supera el presupuesto maximo definido en profiles.yaml."
    }
  }
}

module "sandbox" {
  source   = "../../modules/sandbox-factory"
  for_each = local.teams

  team            = each.value
  prefix          = var.prefix
  folder_id       = local.org.folders.ai_sandbox
  billing_account = var.billing_account
  region          = var.region
  zone            = var.zone

  host_project  = local.net.host_project
  network_id    = local.net.network_id
  sandbox_range = local.net.sandbox_range

  kms_keys           = local.security.kms_keys
  perimeter_name     = local.security.perimeter_name
  perimeter_enforced = local.security.perimeter_enforced

  budget_topic     = local.ai.budget_topic
  platform_project = local.ai.projects.ai_platform.id
  data_project     = local.ai.projects.ai_data.id
  curated_bucket   = local.ai.curated.bucket
  curated_dataset  = local.ai.curated.dataset

  workbench_idle_minutes = var.workbench_idle_minutes
  enforce_gpu_quota      = var.enforce_gpu_quota

  depends_on = [terraform_data.reglas]
}
