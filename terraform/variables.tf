variable "project_id" {
  description = "GCP project ID. MUST be a throwaway/isolated project — this cluster is deliberately insecure."
  type        = string
}

variable "region" {
  description = "GCP region (used by the provider)."
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Zone for the (zonal) cluster + node pool. Zonal keeps it single-control-plane and cheap."
  type        = string
  default     = "us-central1-a"
}

variable "cluster_name" {
  description = "Name of the vulnerable cluster."
  type        = string
  default     = "pentest-sim"
}

variable "kubernetes_version" {
  description = <<-EOT
    Optional exact/min master version (e.g. "1.29."). Leave null to take the channel default.
    An older minor keeps Pod Security defaults permissive and pairs with the pinned vulnerable
    ingress-nginx we install via Helm.
  EOT
  type        = string
  default     = null
}

variable "node_machine_type" {
  description = "Worker node machine type."
  type        = string
  default     = "e2-standard-2"
}

variable "node_count" {
  description = "Worker node count. Keep at 1 so node-breakout blast radius is predictable."
  type        = number
  default     = 1
}
