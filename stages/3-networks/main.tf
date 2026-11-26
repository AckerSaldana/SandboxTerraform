# Etapa 3-networks: red compartida con el plan de IP del sprint 1, salida
# por dominio, DNS privado, conexion hibrida y reserva para Private
# Service Connect.

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

locals {
  org      = data.terraform_remote_state.org.outputs
  net_hub  = local.org.projects.net_hub.id
  security = local.org.projects.security.id

  # Plan de IP sobre 10.64.0.0/10. La primera mitad es de servicios
  # compartidos y la segunda (10.96.0.0/11) de sandboxes, un /16 por equipo.
  subnets = {
    hub-central = { cidr = "10.64.0.0/24", region = var.region }
    hub-east    = { cidr = "10.64.1.0/24", region = var.alt_region }
    psc         = { cidr = "10.64.2.0/24", region = var.region }
    ai-data     = { cidr = "10.66.4.0/24", region = var.region }
    ai-platform = {
      cidr   = "10.66.0.0/22"
      region = var.region
      secondary_ranges = {
        pods     = "10.68.0.0/16"
        services = "10.69.0.0/20"
      }
    }
  }
}

module "hub" {
  source        = "../../modules/network-hub"
  prefix        = var.prefix
  project_id    = local.net_hub
  subnets       = local.subnets
  flow_sampling = var.flow_sampling
}

module "firewall" {
  source          = "../../modules/firewall"
  prefix          = var.prefix
  project_id      = local.net_hub
  network_id      = module.hub.network_id
  network_name    = module.hub.network_name
  folder_id       = local.org.folders.ai_sandbox
  allowed_fqdns   = var.allowed_fqdns
  internal_ranges = [var.platform_range]
}

# ---------------------------------------------------------------------
# Conexion hibrida. Se puede apagar con enable_hybrid para no pagar los
# tuneles cuando no se usan.
# ---------------------------------------------------------------------
data "google_secret_manager_secret_version" "vpn" {
  count   = var.enable_hybrid ? 1 : 0
  project = local.security
  secret  = data.terraform_remote_state.security.outputs.vpn_secret
}

module "hybrid" {
  count                = var.enable_hybrid ? 1 : 0
  source               = "../../modules/hybrid-connectivity"
  prefix               = var.prefix
  project_id           = local.net_hub
  network_id           = module.hub.network_id
  region               = var.region
  shared_secret        = data.google_secret_manager_secret_version.vpn[0].secret_data
  external_gateway_ips = var.onprem_gateway_ips
  onprem_cidr          = var.onprem_cidr
}

# ---------------------------------------------------------------------
# Private Service Connect hacia Vertex AI. Aqui solo se reserva la
# direccion. La regla de reenvio se crea en la etapa 4, con el endpoint.
# ---------------------------------------------------------------------
resource "google_compute_address" "vertex_psc" {
  name         = "${var.prefix}-aisbx-vertex-psc"
  project      = local.net_hub
  region       = var.region
  subnetwork   = module.hub.subnet_ids["psc"]
  address_type = "INTERNAL"
}

# ---------------------------------------------------------------------
# Pruebas de conectividad declaradas como codigo. El pipeline revisa su
# resultado despues de cada apply (tests/red.sh).
# ---------------------------------------------------------------------
resource "google_network_management_connectivity_test" "sin_internet" {
  name        = "${var.prefix}-aisbx-sin-internet"
  project     = local.net_hub
  description = "Desde la plataforma no debe haber salida libre a Internet"
  protocol    = "TCP"

  source {
    ip_address = cidrhost(local.subnets["ai-platform"].cidr, 10)
    network    = module.hub.network_id
    project_id = local.net_hub
  }

  destination {
    ip_address = "8.8.8.8"
    port       = 443
  }
}

resource "google_network_management_connectivity_test" "onprem" {
  count       = var.enable_hybrid && length(var.onprem_gateway_ips) == 0 ? 1 : 0
  name        = "${var.prefix}-aisbx-onprem-a-hub"
  project     = local.net_hub
  description = "La red de la empresa debe llegar a la plataforma por la VPN"
  protocol    = "TCP"

  source {
    ip_address = module.hybrid[0].onprem_test_ip
    network    = module.hybrid[0].onprem_network_id
    project_id = local.net_hub
  }

  destination {
    ip_address = cidrhost(local.subnets["ai-platform"].cidr, 10)
    network    = module.hub.network_id
    port       = 443
  }
}
