locals {
  # Direcciones de enlace para las dos sesiones BGP
  bgp = [
    { hub = "169.254.0.1", onprem = "169.254.0.2" },
    { hub = "169.254.1.1", onprem = "169.254.1.2" },
  ]

  external = length(var.external_gateway_ips) > 0
  simulate = !local.external && var.peer_gcp_gateway == null
  peer_gcp = local.external ? null : (local.simulate ? google_compute_ha_vpn_gateway.onprem[0].id : var.peer_gcp_gateway)
}

# ---------------------------------------------------------------------
# Lado de la plataforma
# ---------------------------------------------------------------------
resource "google_compute_ha_vpn_gateway" "hub" {
  name    = "${var.prefix}-aisbx-vpn"
  project = var.project_id
  region  = var.region
  network = var.network_id
}

resource "google_compute_router" "hub" {
  name    = "${var.prefix}-aisbx-vpn"
  project = var.project_id
  region  = var.region
  network = var.network_id

  bgp {
    asn = var.asn
  }
}

# Sitio fisico: gateway externo con las IP publicas del equipo del cliente
resource "google_compute_external_vpn_gateway" "site" {
  count           = local.external ? 1 : 0
  name            = "${var.prefix}-aisbx-sitio"
  project         = var.project_id
  redundancy_type = length(var.external_gateway_ips) == 2 ? "TWO_IPS_REDUNDANCY" : "SINGLE_IP_INTERNALLY_REDUNDANT"

  dynamic "interface" {
    for_each = var.external_gateway_ips
    content {
      id         = interface.key
      ip_address = interface.value
    }
  }
}

resource "google_compute_vpn_tunnel" "hub" {
  count                 = 2
  name                  = "${var.prefix}-aisbx-tunel-${count.index}"
  project               = var.project_id
  region                = var.region
  vpn_gateway           = google_compute_ha_vpn_gateway.hub.id
  vpn_gateway_interface = count.index
  router                = google_compute_router.hub.id
  shared_secret         = var.shared_secret

  peer_gcp_gateway                = local.peer_gcp
  peer_external_gateway           = local.external ? google_compute_external_vpn_gateway.site[0].id : null
  peer_external_gateway_interface = local.external ? min(count.index, length(var.external_gateway_ips) - 1) : null
}

resource "google_compute_router_interface" "hub" {
  count      = 2
  name       = "tunel-${count.index}"
  project    = var.project_id
  region     = var.region
  router     = google_compute_router.hub.name
  ip_range   = "${local.bgp[count.index].hub}/30"
  vpn_tunnel = google_compute_vpn_tunnel.hub[count.index].name
}

resource "google_compute_router_peer" "hub" {
  count           = 2
  name            = "onprem-${count.index}"
  project         = var.project_id
  region          = var.region
  router          = google_compute_router.hub.name
  peer_ip_address = local.bgp[count.index].onprem
  peer_asn        = var.peer_asn
  interface       = google_compute_router_interface.hub[count.index].name
}

# ---------------------------------------------------------------------
# On-premises simulado: una segunda VPC hace de red de la empresa.
# Usa los mismos recursos que la conexion real.
# ---------------------------------------------------------------------
resource "google_compute_network" "onprem" {
  count                   = local.simulate ? 1 : 0
  name                    = "${var.prefix}-onprem-sim"
  project                 = var.project_id
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"
}

resource "google_compute_subnetwork" "onprem" {
  count         = local.simulate ? 1 : 0
  name          = "${var.prefix}-onprem-sim"
  project       = var.project_id
  network       = google_compute_network.onprem[0].id
  region        = var.region
  ip_cidr_range = var.onprem_cidr
}

resource "google_compute_ha_vpn_gateway" "onprem" {
  count   = local.simulate ? 1 : 0
  name    = "${var.prefix}-onprem-sim-vpn"
  project = var.project_id
  region  = var.region
  network = google_compute_network.onprem[0].id
}

resource "google_compute_router" "onprem" {
  count   = local.simulate ? 1 : 0
  name    = "${var.prefix}-onprem-sim-vpn"
  project = var.project_id
  region  = var.region
  network = google_compute_network.onprem[0].id

  bgp {
    asn = var.peer_asn
  }
}

resource "google_compute_vpn_tunnel" "onprem" {
  count                 = local.simulate ? 2 : 0
  name                  = "${var.prefix}-onprem-sim-tunel-${count.index}"
  project               = var.project_id
  region                = var.region
  vpn_gateway           = google_compute_ha_vpn_gateway.onprem[0].id
  vpn_gateway_interface = count.index
  peer_gcp_gateway      = google_compute_ha_vpn_gateway.hub.id
  router                = google_compute_router.onprem[0].id
  shared_secret         = var.shared_secret
}

resource "google_compute_router_interface" "onprem" {
  count      = local.simulate ? 2 : 0
  name       = "tunel-${count.index}"
  project    = var.project_id
  region     = var.region
  router     = google_compute_router.onprem[0].name
  ip_range   = "${local.bgp[count.index].onprem}/30"
  vpn_tunnel = google_compute_vpn_tunnel.onprem[count.index].name
}

resource "google_compute_router_peer" "onprem" {
  count           = local.simulate ? 2 : 0
  name            = "hub-${count.index}"
  project         = var.project_id
  region          = var.region
  router          = google_compute_router.onprem[0].name
  peer_ip_address = local.bgp[count.index].hub
  peer_asn        = var.asn
  interface       = google_compute_router_interface.onprem[count.index].name
}
