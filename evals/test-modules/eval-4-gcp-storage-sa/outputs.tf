output "bucket_name" {
  description = "Name of the created storage bucket"
  value       = google_storage_bucket.data.name
}

output "bucket_url" {
  description = "gs:// URL of the bucket"
  value       = google_storage_bucket.data.url
}

output "service_account_email" {
  description = "Email of the application service account"
  value       = google_service_account.app.email
}

output "project_number" {
  description = "GCP project number (resolved from project_id)"
  value       = data.google_project.current.number
}
