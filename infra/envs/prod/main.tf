terraform {
  required_version = ">= 1.7.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

variable "project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "us-central1"
}

module "core" {
  source = "../../modules/core"

  project_id                = var.project_id
  region                    = var.region
  environment               = "prod"
  assets_bucket_name        = "${var.project_id}-wl-assets-prod"
  manage_firestore_database = false

  backend_service_env = {
    WELLNESSLENS_USE_FIRESTORE         = "true"
    WELLNESSLENS_FIREBASE_AUTH_ENABLED = "true"
    WELLNESSLENS_APP_CHECK_ENFORCED    = "true"
  }

  agent_service_env = {
    WELLNESSLENS_AGENT_PROVIDER = "vertex"
  }
}
