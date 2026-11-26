# ---------------------------------------------------------------------
# Secure tags: estan gobernadas por IAM. Un cientifico de datos no puede
# etiquetar su maquina para abrirse reglas, como si pasa con network tags.
# ---------------------------------------------------------------------
resource "google_tags_tag_key" "egress" {
  parent      = "projects/${var.project_id}"
  short_name  = "aisbx-salida"
  description = "Controla que cargas pueden salir a los dominios aprobados"
  purpose     = "GCE_FIREWALL"
  purpose_data = {
    network = "${var.project_id}/${var.network_name}"
  }
}

resource "google_tags_tag_value" "repos" {
  parent      = google_tags_tag_key.egress.id
  short_name  = "repos"
  description = "Puede descargar de los repositorios aprobados"
}

# ---------------------------------------------------------------------
# Politica de red: salida a Internet solo por dominio aprobado
# ---------------------------------------------------------------------
resource "google_compute_network_firewall_policy" "egress" {
  name    = "${var.prefix}-aisbx-salida"
  project = var.project_id
}

resource "google_compute_network_firewall_policy_rule" "internal_ingress" {
  firewall_policy = google_compute_network_firewall_policy.egress.name
  project         = var.project_id
  rule_name       = "permitir-entrada-interna"
  priority        = 800
  direction       = "INGRESS"
  action          = "allow"

  match {
    src_ip_ranges = concat(var.internal_ranges, var.health_check_ranges)
    layer4_configs {
      ip_protocol = "all"
    }
  }
}

resource "google_compute_network_firewall_policy_rule" "internal" {
  firewall_policy = google_compute_network_firewall_policy.egress.name
  project         = var.project_id
  rule_name       = "permitir-interno-y-apis"
  priority        = 900
  direction       = "EGRESS"
  action          = "allow"

  match {
    dest_ip_ranges = concat(var.internal_ranges, ["199.36.153.4/30"])
    layer4_configs {
      ip_protocol = "all"
    }
  }
}

resource "google_compute_network_firewall_policy_rule" "fqdns" {
  firewall_policy = google_compute_network_firewall_policy.egress.name
  project         = var.project_id
  rule_name       = "permitir-dominios-aprobados"
  priority        = 1000
  direction       = "EGRESS"
  action          = "allow"
  enable_logging  = true

  match {
    dest_fqdns = var.allowed_fqdns
    layer4_configs {
      ip_protocol = "tcp"
      ports       = ["443"]
    }
  }

  target_secure_tags {
    name = google_tags_tag_value.repos.id
  }
}

resource "google_compute_network_firewall_policy_rule" "deny_all" {
  firewall_policy = google_compute_network_firewall_policy.egress.name
  project         = var.project_id
  rule_name       = "negar-resto"
  priority        = 65000
  direction       = "EGRESS"
  action          = "deny"
  enable_logging  = true

  match {
    dest_ip_ranges = ["0.0.0.0/0"]
    layer4_configs {
      ip_protocol = "all"
    }
  }
}

resource "google_compute_network_firewall_policy_association" "hub" {
  name              = "hub"
  project           = var.project_id
  firewall_policy   = google_compute_network_firewall_policy.egress.name
  attachment_target = var.network_id
}

# ---------------------------------------------------------------------
# Politica jerarquica: reglas que ningun equipo puede cambiar
# ---------------------------------------------------------------------
resource "google_compute_firewall_policy" "base" {
  parent      = var.folder_id
  short_name  = "${var.prefix}-aisbx-base"
  description = "Entrada: solo IAP y trafico interno"
}

resource "google_compute_firewall_policy_rule" "allow_iap" {
  firewall_policy = google_compute_firewall_policy.base.name
  description     = "Acceso administrativo por Identity-Aware Proxy, sin bastion"
  priority        = 100
  direction       = "INGRESS"
  action          = "allow"

  match {
    src_ip_ranges = [var.iap_range]
    layer4_configs {
      ip_protocol = "tcp"
      ports       = ["22", "3389"]
    }
  }
}

resource "google_compute_firewall_policy_rule" "internal_next" {
  firewall_policy = google_compute_firewall_policy.base.name
  description     = "El trafico interno lo decide la politica de red"
  priority        = 200
  direction       = "INGRESS"
  action          = "goto_next"

  match {
    src_ip_ranges = concat(var.internal_ranges, var.health_check_ranges)
    layer4_configs {
      ip_protocol = "all"
    }
  }
}

resource "google_compute_firewall_policy_rule" "deny_ingress" {
  firewall_policy = google_compute_firewall_policy.base.name
  description     = "Ninguna entrada desde Internet"
  priority        = 65000
  direction       = "INGRESS"
  action          = "deny"
  enable_logging  = true

  match {
    src_ip_ranges = ["0.0.0.0/0"]
    layer4_configs {
      ip_protocol = "all"
    }
  }
}

resource "google_compute_firewall_policy_association" "folder" {
  name              = "${var.prefix}-aisbx-base"
  firewall_policy   = google_compute_firewall_policy.base.name
  attachment_target = var.folder_id
}
