resource "google_container_node_pool" "nodepool" {
  name              = var.name
  cluster           = var.cluster
  location          = var.location
  max_pods_per_node = local.max_pods_per_node

  provider = google-beta

  autoscaling {
    min_node_count = local.min_nodes
    max_node_count = max(local.min_nodes, local.max_nodes)
  }

  # when creating new clusters, start with 1 to let the autoscaler kick in, then ignore subsequent changes
  # See: https://cloud.google.com/kubernetes-engine/docs/concepts/cluster-autoscaler#limitations
  initial_node_count = 1

  lifecycle {
    ignore_changes = [
      initial_node_count
    ]
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type    = local.machine_type
    preemptible     = local.preemptible
    service_account = var.service_account.email
    oauth_scopes    = local.oauth_scopes

    labels = merge({ "size" : local.machine_type }, local.labels)
    tags   = concat([var.cluster], local.tags)

    metadata        = {
      disable-legacy-endpoints = true
    }

    dynamic "taint" {
      for_each = local.taints
      content {
        key    = taint.value["key"]
        value  = taint.value["value"]
        effect = taint.value["effect"]
      }
    }
  }

  upgrade_settings {
    max_surge       = local.max_surge
    max_unavailable = local.max_unavailable
  }
}

output "nodepool" {
  value = google_container_node_pool.nodepool
}
