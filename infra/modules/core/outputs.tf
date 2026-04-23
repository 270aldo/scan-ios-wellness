output "artifact_registry_repository" {
  value = google_artifact_registry_repository.containers.id
}

output "assets_bucket_name" {
  value = google_storage_bucket.assets.name
}

output "backend_service_account_email" {
  value = google_service_account.backend_api.email
}

output "agent_service_account_email" {
  value = google_service_account.agent_service.email
}

output "ci_deployer_service_account_email" {
  value = google_service_account.ci_deployer.email
}

output "backend_service_url" {
  value = try(google_cloud_run_v2_service.backend_api[0].uri, null)
}

output "agent_service_url" {
  value = try(google_cloud_run_v2_service.agent_service[0].uri, null)
}
