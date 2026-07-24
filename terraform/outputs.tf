output "cluster_name" {
  value       = google_container_cluster.primary.name
  description = "Cluster name."
}

output "cluster_endpoint" {
  value       = google_container_cluster.primary.endpoint
  description = "Public control-plane endpoint (intentionally reachable)."
  sensitive   = true
}

output "location" {
  value       = google_container_cluster.primary.location
  description = "Cluster zone."
}

output "get_credentials_command" {
  value       = "gcloud container clusters get-credentials ${google_container_cluster.primary.name} --zone ${var.zone} --project ${var.project_id}"
  description = "Run this to populate kubeconfig for kubectl."
}
