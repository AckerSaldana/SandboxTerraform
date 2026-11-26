terraform {
  required_version = ">= 1.9"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.50"
    }
  }

  # El bucket y el prefijo se pasan con -backend-config en el pipeline
  backend "gcs" {}
}

provider "google" {
  region = var.region
}
