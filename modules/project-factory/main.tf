locals {
  project_id = "${var.prefix}-aisbx-${var.name}"
}

resource "google_project" "this" {
  name                = local.project_id
  project_id          = local.project_id
  folder_id           = var.folder_id
  billing_account     = var.billing_account
  labels              = var.labels
  auto_create_network = false
  deletion_policy     = var.deletion_policy
}

resource "google_project_service" "this" {
  for_each           = toset(var.services)
  project            = google_project.this.project_id
  service            = each.key
  disable_on_destroy = false
}

# Proyecto de servicio de la Shared VPC (opcional)
resource "google_compute_shared_vpc_service_project" "this" {
  count           = var.shared_vpc_host == null ? 0 : 1
  host_project    = var.shared_vpc_host
  service_project = google_project.this.project_id

  depends_on = [google_project_service.this]
}
