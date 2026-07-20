terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "2.95.0"
    }
  }
}

provider "digitalocean" {
  token = var.do_token
}

resource "digitalocean_kubernetes_cluster" "lab" {
  name     = var.cluster_name
  region   = var.region
  version  = var.k8s_version
  vpc_uuid = var.vpc_uuid

  node_pool {
    name       = "default"
    size       = var.node_size
    node_count = 1
  }
}