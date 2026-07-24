# =============================================================================
#  Deliberately-vulnerable GKE Standard cluster.
#  Each insecure setting below is annotated with its ground-truth ID (see
#  docs/DESIGN.md and ground-truth/). DO NOT "fix" these — the insecurity is
#  the product. Scope is in-cluster only: node SA scopes are kept minimal so a
#  node breakout does NOT reach GCP APIs.
# =============================================================================

resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.zone # zonal → single control plane, cheap

  # We manage the node pool separately.
  remove_default_node_pool = true
  initial_node_count       = 1

  min_master_version = var.kubernetes_version

  # Let `terraform destroy` actually work on a throwaway lab.
  deletion_protection = false

  # --- [CLUSTER-LEVEL PLANTED WEAKNESSES] --------------------------------------

  # V-EDGE: Public control-plane endpoint reachable from anywhere.
  # (No private_cluster_config block == public endpoint.)
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "0.0.0.0/0"
      display_name = "world-open-INTENTIONALLY-INSECURE"
    }
  }

  # V-ABAC: Legacy ABAC authorization enabled — grants broad implicit access and
  # undercuts RBAC. Classic misconfiguration.
  enable_legacy_abac = true

  # V23: NetworkPolicy disabled → flat pod network, unrestricted lateral movement.
  network_policy {
    enabled = false
  }

  # No Binary Authorization, no image scanning gate (part of V26).
  # (Simply not configuring binary_authorization leaves admission open.)

  # Workload Identity intentionally NOT enabled (metadata not concealed). Low
  # impact here since node scopes are minimal and cloud pivot is out of scope,
  # but it remains a detectable posture finding.

  # Keep logging/monitoring on so the beacon/audit story is observable.
  logging_service    = "logging.googleapis.com/kubernetes"
  monitoring_service = "monitoring.googleapis.com/kubernetes"

  lifecycle {
    ignore_changes = [initial_node_count]
  }
}

resource "google_container_node_pool" "primary_nodes" {
  name       = "${var.cluster_name}-nodes"
  location   = var.zone
  cluster    = google_container_cluster.primary.name
  node_count = var.node_count

  node_config {
    machine_type = var.node_machine_type
    disk_size_gb = 50
    image_type   = "COS_CONTAINERD"

    # V-SCOPE-CONTAINMENT: minimal OAuth scopes on the node service account.
    # This is a DELIBERATE guardrail, not a vuln: it keeps a node breakout from
    # reaching GCP APIs (GCS/BigQuery/IAM), per the in-cluster-only scope.
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]

    # Metadata server left at defaults (GCE_METADATA exposed) — but harmless
    # given the minimal scopes above.
    metadata = {
      disable-legacy-endpoints = "true"
    }

    labels = {
      purpose = "pentest-sim"
    }

    # No Shielded VM hardening flags set → another minor posture finding.
  }

  management {
    auto_repair  = true
    auto_upgrade = false # pin the version so the lab stays reproducible
  }
}
