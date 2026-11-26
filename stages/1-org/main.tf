# Etapa 1-org: carpetas, proyectos comunes, politicas de organizacion,
# auditoria centralizada y acceso temporal del equipo de plataforma.

locals {
  org     = "organizations/${var.org_id}"
  sandbox = google_folder.ai_sandbox.name

  labels = {
    team        = "plataforma"
    owner       = "plataforma"
    cost_center = var.cost_center
    expires     = "no-expira"
    managed_by  = "terraform"
  }
}

# ---------------------------------------------------------------------
# Carpetas
# ---------------------------------------------------------------------
resource "google_folder" "common" {
  display_name = "common"
  parent       = local.org
}

resource "google_folder" "ai_sandbox" {
  display_name = "ai-sandbox"
  parent       = local.org
}

# Las etapas 4 y 5 crean sus proyectos dentro de ai-sandbox. Reciben
# permisos solo sobre esa carpeta, no sobre la organizacion.
data "terraform_remote_state" "bootstrap" {
  backend = "gcs"
  config = {
    bucket = var.tfstate_bucket
    prefix = "0-bootstrap"
  }
}

locals {
  pipeline = data.terraform_remote_state.bootstrap.outputs.stage_service_accounts

  folder_roles = {
    ai-platform = [
      "roles/resourcemanager.projectCreator",
      "roles/resourcemanager.folderViewer",
      "roles/resourcemanager.folderIamAdmin",
      "roles/compute.xpnAdmin",
    ]
    sandboxes = [
      "roles/resourcemanager.projectCreator",
      "roles/resourcemanager.folderViewer",
      "roles/compute.xpnAdmin",
    ]
  }

  folder_bindings = merge([
    for stage, roles in local.folder_roles : {
      for role in roles : "${stage}:${role}" => { stage = stage, role = role }
    }
  ]...)
}

resource "google_folder_iam_member" "pipeline" {
  for_each = local.folder_bindings
  folder   = google_folder.ai_sandbox.name
  role     = each.value.role
  member   = "serviceAccount:${local.pipeline[each.value.stage]}"
}

# ---------------------------------------------------------------------
# Proyectos comunes
# ---------------------------------------------------------------------
module "net_hub" {
  source          = "../../modules/project-factory"
  prefix          = var.prefix
  name            = "net-hub"
  folder_id       = google_folder.common.name
  billing_account = var.billing_account
  labels          = local.labels
  services = [
    "compute.googleapis.com",
    "dns.googleapis.com",
    "networkmanagement.googleapis.com",
    "networksecurity.googleapis.com",
    "iap.googleapis.com",
  ]
}

module "logging" {
  source          = "../../modules/project-factory"
  prefix          = var.prefix
  name            = "logging"
  folder_id       = google_folder.common.name
  billing_account = var.billing_account
  labels          = local.labels
  services = [
    "logging.googleapis.com",
    "bigquery.googleapis.com",
    "monitoring.googleapis.com",
  ]
}

module "security" {
  source          = "../../modules/project-factory"
  prefix          = var.prefix
  name            = "security"
  folder_id       = google_folder.common.name
  billing_account = var.billing_account
  labels          = local.labels
  services = [
    "cloudkms.googleapis.com",
    "secretmanager.googleapis.com",
    "dlp.googleapis.com",
  ]
}

# Permisos de cada etapa sobre los proyectos comunes. Cada cuenta recibe
# solo los roles del proyecto que administra.
locals {
  project_roles = {
    security = {
      security = ["roles/cloudkms.admin", "roles/secretmanager.admin"]
      logging  = ["roles/bigquery.admin"]
    }
    networks = {
      net_hub = [
        "roles/compute.networkAdmin",
        "roles/compute.securityAdmin",
        "roles/dns.admin",
        "roles/resourcemanager.tagAdmin",
        "roles/networkmanagement.admin",
      ]
      security = ["roles/secretmanager.secretAccessor"]
    }
    ai-platform = {
      # projectIamAdmin: los agentes de GKE deben poder usar la red anfitriona
      net_hub  = ["roles/compute.networkAdmin", "roles/resourcemanager.tagUser", "roles/resourcemanager.projectIamAdmin"]
      security = ["roles/cloudkms.admin"]
      logging  = ["roles/bigquery.admin"]
    }
    sandboxes = {
      net_hub  = ["roles/compute.networkAdmin"]
      security = ["roles/cloudkms.admin"]
    }
  }

  common_projects = {
    net_hub  = module.net_hub.project_id
    logging  = module.logging.project_id
    security = module.security.project_id
  }

  project_bindings = merge(flatten([
    for stage, projects in local.project_roles : [
      for project, roles in projects : {
        for role in roles : "${stage}:${project}:${role}" => { stage = stage, project = project, role = role }
      }
    ]
  ])...)
}

resource "google_project_iam_member" "pipeline" {
  for_each = local.project_bindings
  project  = local.common_projects[each.value.project]
  role     = each.value.role
  member   = "serviceAccount:${local.pipeline[each.value.stage]}"
}

# ---------------------------------------------------------------------
# Politicas de organizacion
# ---------------------------------------------------------------------
resource "google_org_policy_policy" "regiones" {
  name   = "${local.org}/policies/gcp.resourceLocations"
  parent = local.org

  spec {
    rules {
      values {
        allowed_values = [for r in [var.region, var.alt_region] : "in:${r}-locations"]
      }
    }
  }
}

resource "google_org_policy_policy" "sin_llaves" {
  name   = "${local.org}/policies/iam.disableServiceAccountKeyCreation"
  parent = local.org

  spec {
    rules {
      enforce = "TRUE"
    }
  }
}

# La politica impide que el recurso llegue a existir. El firewall solo
# bloquearia el trafico de un recurso que ya se creo mal.
resource "google_org_policy_policy" "sin_ip_publica" {
  name   = "${local.sandbox}/policies/compute.vmExternalIpAccess"
  parent = local.sandbox

  spec {
    rules {
      deny_all = "TRUE"
    }
  }
}

# Las GPU H100 solo se entregan con solicitud. La regla vive en la API,
# asi que tampoco se puede saltar desde la consola o un notebook.
resource "google_org_policy_custom_constraint" "sin_h100" {
  name           = "custom.aisbxSinH100"
  parent         = local.org
  display_name   = "Las maquinas A3 (H100) requieren solicitud"
  description    = "Bloquea las maquinas A3 en la carpeta ai-sandbox. Se exceptua por proyecto cuando hay aprobacion."
  action_type    = "DENY"
  condition      = "resource.machineType.contains('/machineTypes/a3-')"
  method_types   = ["CREATE"]
  resource_types = ["compute.googleapis.com/Instance"]
}

resource "google_org_policy_policy" "sin_h100" {
  name   = "${local.sandbox}/policies/${google_org_policy_custom_constraint.sin_h100.name}"
  parent = local.sandbox

  spec {
    rules {
      enforce = "TRUE"
    }
  }
}

# ---------------------------------------------------------------------
# Auditoria centralizada
# ---------------------------------------------------------------------
module "observability" {
  source             = "../../modules/observability"
  org_id             = var.org_id
  project_id         = module.logging.project_id
  location           = var.region
  data_access_folder = google_folder.ai_sandbox.folder_id
}

# ---------------------------------------------------------------------
# Acceso temporal: el equipo de plataforma no tiene permisos permanentes
# sobre los datos de los equipos. Los pide con justificacion, los aprueba
# el dueno de los datos y duran como maximo una hora.
# ---------------------------------------------------------------------
resource "google_privileged_access_manager_entitlement" "datos" {
  entitlement_id       = "plataforma-lectura-datos"
  location             = "global"
  parent               = local.sandbox
  max_request_duration = "3600s"

  eligible_users {
    principals = ["group:${var.platform_group}"]
  }

  privileged_access {
    gcp_iam_access {
      resource      = "//cloudresourcemanager.googleapis.com/${local.sandbox}"
      resource_type = "cloudresourcemanager.googleapis.com/Folder"

      role_bindings {
        role = "roles/bigquery.dataViewer"
      }
      role_bindings {
        role = "roles/storage.objectViewer"
      }
    }
  }

  requester_justification_config {
    unstructured {}
  }

  approval_workflow {
    manual_approvals {
      require_approver_justification = true

      steps {
        approvals_needed = 1

        approvers {
          principals = ["group:${var.data_owners_group}"]
        }
      }
    }
  }
}
