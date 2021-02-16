# REQUIRED
variable cluster {}
variable location {}
variable name {}
variable service_account { type = object({ email = string }) }

# OPTIONAL
# See locals{} below for default values
# Defaults are specified this way so that we can define nodepool objects sparsely in root tfvars
variable auto_upgrade { type = bool }
variable labels { default = {} }
variable machine_type { type = string }
variable max_nodes { type = number }
variable max_pods_per_node { type = number }
variable max_surge { type = number }
variable max_unavailable { type = number }
variable min_nodes { type = number }
variable oauth_scopes { type = list(string) }
variable preemptible { type = bool }
variable tags { default = [] }

variable taints {
  default = []
  type = list(object({
    effect = string
    key    = string
    value  = string
  }))
}

locals {
  labels                   = coalesce(var.labels, {})
  auto_upgrade             = coalesce(var.auto_upgrade, true)
  machine_type             = coalesce(var.machine_type, "e2-standard-4")
  max_nodes                = coalesce(var.max_nodes, 0)
  max_pods_per_node        = coalesce(var.max_pods_per_node, 30)
  max_surge                = coalesce(var.max_surge, 2)
  max_unavailable          = coalesce(var.max_unavailable, 0)
  min_nodes                = coalesce(var.min_nodes, 0)
  oauth_scopes = coalesce(var.oauth_scopes, [
    "https://www.googleapis.com/auth/compute",
    "https://www.googleapis.com/auth/devstorage.read_only",
    "https://www.googleapis.com/auth/logging.write",
    "https://www.googleapis.com/auth/monitoring",
  ])
  preemptible = coalesce(var.preemptible, false)
  tags        = coalesce(var.tags, [])
  taints      = coalesce(var.taints, [])
}
