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
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.7"
    }
  }

  # El bucket y el prefijo se pasan con -backend-config en el pipeline
  backend "gcs" {}
}

provider "google" {
  region = var.region
}

provider "google-beta" {
  region = var.region
}
