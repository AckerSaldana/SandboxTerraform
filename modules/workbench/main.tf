# Notebook de Vertex AI Workbench sin IP publica, con disco cifrado y
# apagado automatico por inactividad.
resource "google_workbench_instance" "this" {
  name            = var.name
  project         = var.project_id
  location        = var.zone
  labels          = var.labels
  instance_owners = var.owners

  gce_setup {
    machine_type      = var.machine_type
    disable_public_ip = true

    metadata = {
      # 0 GPU ni notebooks ociosos por mas de 60 minutos
      "idle-timeout-seconds" = tostring(var.idle_minutes * 60)
    }

    network_interfaces {
      network = var.network_id
      subnet  = var.subnet_id
    }

    boot_disk {
      disk_size_gb    = 150
      disk_encryption = "CMEK"
      kms_key         = var.kms_key
    }

    data_disks {
      disk_size_gb    = var.data_disk_gb
      disk_encryption = "CMEK"
      kms_key         = var.kms_key
    }

    service_accounts {
      email = var.service_account
    }

    dynamic "accelerator_configs" {
      for_each = var.gpu_type == null ? [] : [1]
      content {
        type       = var.gpu_type
        core_count = 1
      }
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_vtpm                 = true
      enable_integrity_monitoring = true
    }
  }
}
