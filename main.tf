# Enable APIs
resource "google_project_service" "enable_compute_engine" {
  for_each = var.apis

  service = each.value
  project = var.project
}

resource "google_service_account" "cluster" {
  account_id = "${var.cluster}-cluster-nodes"
}

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

resource "google_storage_bucket_iam_member" "cluster_registry_access" {
  bucket = "artifacts.expel-engineering-devops.appspot.com"
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.cluster.email}"
}

#data "google_compute_network" "cluster" {
#  name = var.environment
#}

#resource "google_compute_subnetwork" "cluster" {
#  name          = "cluster-nodes-${var.cluster}"
#  network       = data.google_compute_network.cluster.self_link
#  project       = var.project
#  region        = var.region
#  ip_cidr_range = var.subnet_ip_cidr_range
#
#  secondary_ip_range {
#    range_name    = "secondary-pods-${var.cluster}"
#    ip_cidr_range = var.pods_ip_cidr_range
#  }
#
#  secondary_ip_range {
#    range_name    = "secondary-services-${var.cluster}"
#    ip_cidr_range = var.services_ip_cidr_range
#  }
#
#  private_ip_google_access = var.enable_private_nodes
#}

resource "google_container_cluster" "cluster" {
  name       = var.cluster
  location   = var.region
  #network    = data.google_compute_network.cluster.self_link
  #subnetwork = google_compute_subnetwork.cluster.self_link

  #provider = google-beta

  enable_shielded_nodes = true

  #ip_allocation_policy {
  #  cluster_secondary_range_name  = "secondary-pods-${var.cluster}"
  #  services_secondary_range_name = "secondary-services-${var.cluster}"
  #}

  # This prevents terraform from wanting recreate the
  # cluster when taints change
  # https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster#taint
  lifecycle {
    ignore_changes = [node_pool]
  }

  # Set maintance window to off hours on weekends
  maintenance_policy {
    recurring_window { # EST: 8PM - 8AM
      end_time   = "2020-01-01T13:00:00Z"
      recurrence = "FREQ=WEEKLY;BYDAY=SA,SU"
      start_time = "2020-01-01T01:00:00Z"
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
    enabled = false
  }
}

module nodepool {
  for_each = var.nodepools
  source   = "./modules/nodepool"

  cluster         = var.cluster
  location        = var.region
  name            = each.key
  service_account = google_service_account.cluster

  enable_workload_identity = lookup(each.value, "enable_workload_identity", null)
  labels                   = lookup(each.value, "labels", null)
  machine_type             = lookup(each.value, "machine_type", null)
  max_nodes                = lookup(each.value, "max_nodes", null)
  max_pods_per_node        = lookup(each.value, "max_pods_per_node", null)
  max_surge                = lookup(each.value, "max_surge", null)
  max_unavailable          = lookup(each.value, "max_unavailable", null)
  min_nodes                = lookup(each.value, "min_nodes", null)
  oauth_scopes             = lookup(each.value, "oauth_scopes", null)
  preemptible              = lookup(each.value, "preemptible", null)
  tags                     = lookup(each.value, "tags", null)
  taints                   = lookup(each.value, "taints", null)

  depends_on = [google_container_cluster.cluster]
}
