variable "cluster" {}

variable "nodepools" {
  description = "Map of cluster node pools with their respective configuration. Attributes with value set to null may be replaced with a default value."
  type = map(object({
    auto_upgrade      = bool
    machine_type      = string
    preemptible       = bool
    max_nodes         = number
    max_pods_per_node = number
    max_surge         = number
    min_nodes         = number
    labels            = map(any)
    tags              = list(string)
    taints = list(object({
      effect = string,
      key    = string,
      value  = string
    }))
  }))
  default = {}
}

variable "project" {
  description = "GCP project to use"
  type        = string
}

variable "region" {
  description = "GCP region to use"
  type        = string
}

variable "release_channel" {
  description = "Which GKE release channel to follow https://cloud.google.com/kubernetes-engine/docs/concepts/release-channels"
  type        = string
}
