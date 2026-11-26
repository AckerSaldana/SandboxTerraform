# Etapa 2-security: llaves de cifrado, politicas de CMEK, secreto de la
# VPN y perimetro de VPC Service Controls en dos pasos.

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

locals {
  org      = data.terraform_remote_state.org.outputs
  sandbox  = local.org.folders.ai_sandbox
  security = local.org.projects.security.id
  logging  = local.org.projects.logging.id
  pipeline = data.terraform_remote_state.bootstrap.outputs.stage_service_accounts
}

# ---------------------------------------------------------------------
# Llaves: modulo clasico con una llave por servicio. Se descarto Autokey
# porque sus KeyHandle no se pueden borrar y rompen el despliegue desde cero.
# ---------------------------------------------------------------------
module "kms" {
  source       = "../../modules/kms"
  project_id   = local.security
  location     = var.region
  keyring_name = "${var.prefix}-aisbx"
  keys         = ["storage", "bigquery", "vertex", "compute", "artifacts", "pubsub"]
}

# Las politicas solo aplican a recursos nuevos. Por eso se activan aqui,
# antes de que exista cualquier recurso de datos o de IA.
resource "google_org_policy_policy" "exigir_cmek" {
  name   = "${local.sandbox}/policies/gcp.restrictNonCmekServices"
  parent = local.sandbox

  spec {
    rules {
      values {
        denied_values = [for s in var.cmek_services : "is:${s}"]
      }
    }
  }
}

resource "google_org_policy_policy" "origen_llaves" {
  name   = "${local.sandbox}/policies/gcp.restrictCmekCryptoKeyProjects"
  parent = local.sandbox

  spec {
    rules {
      values {
        allowed_values = ["under:projects/${local.security}"]
      }
    }
  }
}

# ---------------------------------------------------------------------
# Secreto compartido de la VPN. Aqui solo se crea el contenedor. El valor
# se carga a mano una vez, nunca desde el codigo:
#   gcloud secrets versions add vpn-shared-secret --data-file=-
# ---------------------------------------------------------------------
resource "google_secret_manager_secret" "vpn" {
  project   = local.security
  secret_id = "vpn-shared-secret"
  labels    = local.org.labels

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }
}

# ---------------------------------------------------------------------
# Perimetro. Los proyectos de IA y de cada sandbox se agregan desde las
# etapas 4 y 5.
# ---------------------------------------------------------------------
module "vpc_sc" {
  source                   = "../../modules/vpc-sc"
  org_id                   = var.org_id
  access_policy            = var.access_policy
  enforced                 = var.perimeter_enforced
  restricted_services      = var.restricted_services
  ingress_service_accounts = values(local.pipeline)
  logging_project          = local.logging
  location                 = var.region
  labels                   = local.org.labels
}
