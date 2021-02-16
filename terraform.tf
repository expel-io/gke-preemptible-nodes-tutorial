terraform {
  required_version = "0.14.6"
}

provider "google" {
  project = var.project
  region  = var.region
}

provider "google-beta" {
  version = "~> 3.51.0"
  project = var.project
  region  = var.region
}
