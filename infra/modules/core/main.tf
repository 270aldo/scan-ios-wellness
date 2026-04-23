locals {
  required_services = toset([
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "firebase.googleapis.com",
    "firebasemanagement.googleapis.com",
    "firestore.googleapis.com",
    "iam.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
    "storage.googleapis.com",
    "vertexai.googleapis.com",
  ])

  common_labels = merge(var.labels, {
    app         = "wellnesslens"
    environment = var.environment
    managed_by  = "terraform"
  })
}

resource "google_project_service" "required" {
  for_each = local.required_services

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_service_account" "backend_api" {
  account_id   = "wl-backend-api-${var.environment}"
  display_name = "WellnessLens Backend API (${var.environment})"
  project      = var.project_id
}

resource "google_service_account" "agent_service" {
  account_id   = "wl-agent-service-${var.environment}"
  display_name = "WellnessLens Agent Service (${var.environment})"
  project      = var.project_id
}

resource "google_service_account" "ci_deployer" {
  account_id   = "wl-ci-deployer-${var.environment}"
  display_name = "WellnessLens CI Deployer (${var.environment})"
  project      = var.project_id
}

resource "google_project_iam_member" "backend_firestore_user" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.backend_api.email}"

  depends_on = [google_project_service.required]
}

resource "google_project_iam_member" "agent_vertex_user" {
  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.agent_service.email}"

  depends_on = [google_project_service.required]
}

resource "google_artifact_registry_repository" "containers" {
  project       = var.project_id
  location      = var.region
  repository_id = var.artifact_repository_id
  description   = "Container images for WellnessLens ${var.environment}"
  format        = "DOCKER"
  labels        = local.common_labels

  depends_on = [google_project_service.required]
}

resource "google_storage_bucket" "assets" {
  project                     = var.project_id
  name                        = var.assets_bucket_name
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false
  labels                      = local.common_labels

  versioning {
    enabled = true
  }

  depends_on = [google_project_service.required]
}

resource "google_secret_manager_secret" "firebase_admin" {
  project   = var.project_id
  secret_id = "firebase-admin-json"

  replication {
    auto {}
  }

  labels = local.common_labels
}

resource "google_secret_manager_secret" "app_store" {
  project   = var.project_id
  secret_id = "app-store-connect"

  replication {
    auto {}
  }

  labels = local.common_labels
}

resource "google_secret_manager_secret" "vertex" {
  project   = var.project_id
  secret_id = "vertex-runtime"

  replication {
    auto {}
  }

  labels = local.common_labels
}

resource "google_firestore_database" "default" {
  count       = var.manage_firestore_database ? 1 : 0
  project     = var.project_id
  name        = "(default)"
  location_id = var.region
  type        = "FIRESTORE_NATIVE"

  depends_on = [google_project_service.required]
}

resource "google_cloud_run_v2_service" "backend_api" {
  count    = var.backend_image == null ? 0 : 1
  project  = var.project_id
  name     = "wellnesslens-backend-${var.environment}"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = google_service_account.backend_api.email
    labels          = local.common_labels

    containers {
      image = var.backend_image

      dynamic "env" {
        for_each = merge(var.backend_service_env, {
          WELLNESSLENS_ENV = var.environment
        })
        content {
          name  = env.key
          value = env.value
        }
      }
    }
  }

  deletion_protection = false

  depends_on = [
    google_project_service.required,
    google_artifact_registry_repository.containers,
  ]
}

resource "google_cloud_run_v2_service" "agent_service" {
  count    = var.agent_image == null ? 0 : 1
  project  = var.project_id
  name     = "wellnesslens-agent-${var.environment}"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = google_service_account.agent_service.email
    labels          = local.common_labels

    containers {
      image = var.agent_image

      dynamic "env" {
        for_each = merge(var.agent_service_env, {
          WELLNESSLENS_AGENT_ENV = var.environment
        })
        content {
          name  = env.key
          value = env.value
        }
      }
    }
  }

  deletion_protection = false

  depends_on = [
    google_project_service.required,
    google_artifact_registry_repository.containers,
  ]
}
