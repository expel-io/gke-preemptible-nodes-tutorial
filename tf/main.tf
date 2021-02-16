resource "google_service_account" "cluster" {
  account_id = "${var.cluster}-cluster-nodes"
}

# Default service account has way too many perms,
# so create one and give least privs
resource "google_project_iam_member" "cluster" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/storage.objectViewer",
  ])
  role   = each.key
  member = "serviceAccount:${google_service_account.cluster.email}"
}

resource "google_container_cluster" "cluster" {
  name     = var.cluster
  location = var.region

  provider = google-beta

  enable_shielded_nodes = true

  release_channel {
    channel = var.release_channel
  }

  networking_mode = "VPC_NATIVE"

  ip_allocation_policy {
    # Empty lets GKE manage them
    cluster_ipv4_cidr_block  = ""
    services_ipv4_cidr_block = ""
  }

  # This prevents terraform from wanting recreate the
  # cluster when taints change
  # https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster#taint
  lifecycle {
    ignore_changes = [node_pool]
  }

  # Set maintance window to off hours on weekends
  maintenance_policy {
    recurring_window {
      end_time   = var.maintenance_window["end_time"]
      start_time = var.maintenance_window["start_time"]
      recurrence = var.maintenance_window["recurrence"]
    }
  }

  master_auth {
    password = ""
    username = ""
  }

  node_pool {
    name = "default-pool"
  }

  pod_security_policy_config {
    enabled = true
  }

  vertical_pod_autoscaling {
    enabled = true
  }
}

module "nodepool" {
  for_each = var.nodepools
  source   = "./modules/nodepool"

  cluster         = var.cluster
  location        = var.region
  name            = each.key
  service_account = google_service_account.cluster

  auto_upgrade      = lookup(each.value, "auto_upgrade", null)
  labels            = lookup(each.value, "labels", null)
  machine_type      = lookup(each.value, "machine_type", null)
  max_nodes         = lookup(each.value, "max_nodes", null)
  max_pods_per_node = lookup(each.value, "max_pods_per_node", null)
  max_surge         = lookup(each.value, "max_surge", null)
  max_unavailable   = lookup(each.value, "max_unavailable", null)
  min_nodes         = lookup(each.value, "min_nodes", null)
  oauth_scopes      = lookup(each.value, "oauth_scopes", null)
  preemptible       = lookup(each.value, "preemptible", null)
  tags              = lookup(each.value, "tags", null)
  taints            = lookup(each.value, "taints", null)

  depends_on = [google_container_cluster.cluster]
}
