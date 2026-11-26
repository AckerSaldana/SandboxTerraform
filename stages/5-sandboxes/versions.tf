terraform {
  required_version = ">= 1.9"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.50"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 6.50"
    }
  }

  # El bucket y el prefijo se pasan con -backend-config en el pipeline
  backend "gcs" {}
}

# Los presupuestos usan la API de Cloud Billing, que necesita un proyecto
# de cuota: el proyecto semilla.
provider "google" {
  region                = var.region
  user_project_override = true
  billing_project       = data.terraform_remote_state.bootstrap.outputs.seed_project_id
}

provider "google-beta" {
  region = var.region
}
