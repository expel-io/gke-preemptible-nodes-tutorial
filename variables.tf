variable "apis" {
  description = "List of GCP APIs to enable"
  type        = list(string)
}

variable "cluster" {}

variable "nodepools" {
  description = "Map of cluster node pools with their respective configuration. Attributes with value set to null may be replaced with a default value."
  type = map(object({
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

#variable "pods_ip_cidr_range" {
#  type    = string
#  default = "10.16.0.0/14"
#}

variable "project" {}

variable "region" {}

#variable "services_ip_cidr_range" {
#  type    = string
#  default = "10.128.32.0/20"
#}
#
#variable "subnet_ip_cidr_range" {
#  type    = string
#  default = "10.142.0.0/20"
#}
