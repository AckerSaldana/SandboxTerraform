locals {
  # VIP restringido: solo responden los servicios compatibles con VPC Service Controls
  restricted_ips = ["199.36.153.4", "199.36.153.5", "199.36.153.6", "199.36.153.7"]
  nat_regions    = toset([for s in var.subnets : s.region])
}

resource "google_compute_network" "hub" {
  name                    = "${var.prefix}-aisbx-hub"
  project                 = var.project_id
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"
}

resource "google_compute_shared_vpc_host_project" "hub" {
  project = var.project_id
}

resource "google_compute_subnetwork" "base" {
  for_each                 = var.subnets
  name                     = "${var.prefix}-aisbx-${each.key}"
  project                  = var.project_id
  network                  = google_compute_network.hub.id
  region                   = each.value.region
  ip_cidr_range            = each.value.cidr
  private_ip_google_access = true

  dynamic "secondary_ip_range" {
    for_each = each.value.secondary_ranges
    content {
      range_name    = secondary_ip_range.key
      ip_cidr_range = secondary_ip_range.value
    }
  }

  log_config {
    aggregation_interval = "INTERVAL_10_MIN"
    flow_sampling        = var.flow_sampling
  }
}

# Cloud NAT solo traduce direcciones. El filtrado por dominio lo hace el firewall.
resource "google_compute_router" "nat" {
  for_each = local.nat_regions
  name     = "${var.prefix}-aisbx-nat-${each.key}"
  project  = var.project_id
  region   = each.key
  network  = google_compute_network.hub.id
}

resource "google_compute_router_nat" "nat" {
  for_each                           = local.nat_regions
  name                               = "${var.prefix}-aisbx-nat-${each.key}"
  project                            = var.project_id
  region                             = each.key
  router                             = google_compute_router.nat[each.key].name
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# DNS privado: las API de Google se resuelven hacia el VIP restringido
resource "google_dns_managed_zone" "googleapis" {
  name       = "googleapis"
  project    = var.project_id
  dns_name   = "googleapis.com."
  visibility = "private"

  private_visibility_config {
    networks {
      network_url = google_compute_network.hub.id
    }
  }
}

resource "google_dns_record_set" "restricted" {
  name         = "restricted.googleapis.com."
  project      = var.project_id
  managed_zone = google_dns_managed_zone.googleapis.name
  type         = "A"
  ttl          = 300
  rrdatas      = local.restricted_ips
}

resource "google_dns_record_set" "googleapis_wildcard" {
  name         = "*.googleapis.com."
  project      = var.project_id
  managed_zone = google_dns_managed_zone.googleapis.name
  type         = "CNAME"
  ttl          = 300
  rrdatas      = ["restricted.googleapis.com."]
}

# Artifact Registry y Container Registry tambien pasan por el VIP restringido
resource "google_dns_managed_zone" "registry" {
  for_each   = toset(["pkg.dev", "gcr.io"])
  name       = replace(each.key, ".", "-")
  project    = var.project_id
  dns_name   = "${each.key}."
  visibility = "private"

  private_visibility_config {
    networks {
      network_url = google_compute_network.hub.id
    }
  }
}

resource "google_dns_record_set" "registry_apex" {
  for_each     = google_dns_managed_zone.registry
  name         = each.value.dns_name
  project      = var.project_id
  managed_zone = each.value.name
  type         = "A"
  ttl          = 300
  rrdatas      = local.restricted_ips
}

resource "google_dns_record_set" "registry_wildcard" {
  for_each     = google_dns_managed_zone.registry
  name         = "*.${each.value.dns_name}"
  project      = var.project_id
  managed_zone = each.value.name
  type         = "CNAME"
  ttl          = 300
  rrdatas      = [each.value.dns_name]
}
