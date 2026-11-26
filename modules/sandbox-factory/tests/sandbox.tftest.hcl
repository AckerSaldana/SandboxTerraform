# Pruebas de la fabrica con proveedores simulados: no crean nada en GCP.
# Ejecutar con: terraform test (desde modules/sandbox-factory)

mock_provider "google" {
  mock_resource "google_service_account" {
    defaults = {
      name  = "projects/acme-aisbx-vision/serviceAccounts/sa-vision@acme-aisbx-vision.iam.gserviceaccount.com"
      email = "sa-vision@acme-aisbx-vision.iam.gserviceaccount.com"
    }
  }
}
mock_provider "google-beta" {}

variables {
  prefix          = "acme"
  folder_id       = "folders/123456789"
  billing_account = "000000-AAAAAA-BBBBBB"
  region          = "us-central1"
  zone            = "us-central1-a"
  host_project    = "acme-aisbx-net-hub"
  network_id      = "projects/acme-aisbx-net-hub/global/networks/acme-aisbx-vpc"
  kms_keys = {
    storage  = "projects/p/locations/us-central1/keyRings/k/cryptoKeys/storage"
    bigquery = "projects/p/locations/us-central1/keyRings/k/cryptoKeys/bigquery"
    compute  = "projects/p/locations/us-central1/keyRings/k/cryptoKeys/compute"
  }
  perimeter_name     = "accessPolicies/1/servicePerimeters/aisbx"
  perimeter_enforced = false
  budget_topic       = "projects/acme-aisbx-ai-platform/topics/presupuestos"
  platform_project   = "acme-aisbx-ai-platform"
  data_project       = "acme-aisbx-ai-data"
  curated_bucket     = "acme-aisbx-curated"
  curated_dataset    = "curated"

  team = {
    name               = "vision"
    owner_group        = "gcp-vision@example.com"
    cost_center        = "cc-2210"
    expires            = "2027-02-28"
    profile            = "finetuning"
    size               = "m"
    subnet_index       = 1
    monthly_budget_usd = 1500
    gpu_quota          = { l4 = 2, a100 = 1 }
    services           = ["aiplatform.googleapis.com", "compute.googleapis.com"]
    roles              = ["roles/aiplatform.user"]
    data_access        = ["curated"]
    workbench          = true
  }
}

run "red_y_etiquetas" {
  command = plan

  assert {
    condition     = output.subnet_cidr == "10.97.0.0/16"
    error_message = "El indice 1 debe recibir el segundo /16 del rango de sandboxes."
  }

  assert {
    condition     = output.labels.team == "vision" && output.labels.cost_center == "cc-2210"
    error_message = "Las etiquetas de costo deben salir del archivo del equipo."
  }

  assert {
    condition     = output.labels.profile == "finetuning" && output.labels.size == "m"
    error_message = "El perfil y la talla deben quedar como etiquetas."
  }
}

run "presupuesto_y_perimetro" {
  command = plan

  assert {
    condition     = google_billing_budget.this.amount[0].specified_amount[0].units == "1500"
    error_message = "El presupuesto debe ser el de la talla."
  }

  assert {
    condition     = length(google_billing_budget.this.threshold_rules) == 3
    error_message = "Deben existir alertas al 50, 80 y 100 %."
  }

  assert {
    condition     = length(google_access_context_manager_service_perimeter_dry_run_resource.dry_run) == 1
    error_message = "Con el perimetro en prueba, el proyecto entra en modo de prueba."
  }

  assert {
    condition     = length(google_org_policy_policy.allow_h100) == 0
    error_message = "Sin cuota de H100 no debe existir la excepcion."
  }
}

run "sin_datos_no_hay_lectura" {
  command = plan

  variables {
    team = {
      name               = "abiertos"
      owner_group        = "gcp-abiertos@example.com"
      cost_center        = "cc-3000"
      expires            = "2027-01-31"
      profile            = "modelos-abiertos"
      size               = "s"
      subnet_index       = 2
      monthly_budget_usd = 500
      gpu_quota          = { l4 = 1 }
      services           = ["aiplatform.googleapis.com"]
      roles              = ["roles/aiplatform.user"]
      data_access        = []
      workbench          = false
    }
  }

  assert {
    condition     = length(google_storage_bucket_iam_member.curated) == 0
    error_message = "Un perfil sin acceso a datos no debe leer la zona curated."
  }

  assert {
    condition     = length(module.workbench) == 0
    error_message = "Este perfil no incluye notebook."
  }
}

run "raw_se_rechaza" {
  command = plan

  variables {
    team = {
      name               = "malo"
      owner_group        = "gcp-malo@example.com"
      cost_center        = "cc-0001"
      expires            = "2027-01-31"
      profile            = "rag"
      size               = "s"
      subnet_index       = 3
      monthly_budget_usd = 300
      gpu_quota          = {}
      services           = []
      roles              = []
      data_access        = ["raw"]
      workbench          = false
    }
  }

  expect_failures = [var.team]
}
