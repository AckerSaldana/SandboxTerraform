# Subred de un sandbox. En una Shared VPC la subred vive en el proyecto
# anfitrion (net-hub) y solo se comparte con el proyecto del equipo.
resource "google_compute_subnetwork" "this" {
  name                     = "${var.prefix}-aisbx-${var.name}"
  project                  = var.host_project
  network                  = var.network_id
  region                   = var.region
  ip_cidr_range            = var.cidr
  private_ip_google_access = true

  log_config {
    aggregation_interval = "INTERVAL_10_MIN"
    flow_sampling        = var.flow_sampling
  }
}

resource "google_compute_subnetwork_iam_member" "user" {
  for_each   = var.users
  project    = var.host_project
  region     = var.region
  subnetwork = google_compute_subnetwork.this.name
  role       = "roles/compute.networkUser"
  member     = each.value
}
