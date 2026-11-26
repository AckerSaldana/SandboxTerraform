terraform {
  required_version = ">= 1.9"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.50"
    }
  }

  # Primer apply: estado local (este bloque queda comentado).
  # Despues del primer apply se descomenta y se ejecuta:
  #   terraform init -migrate-state
  # Un segundo terraform plan debe salir sin cambios.
  #
  # backend "gcs" {
  #   bucket = "<prefijo>-aisbx-tfstate"
  #   prefix = "0-bootstrap"
  # }
}

provider "google" {
  region = var.region
}
