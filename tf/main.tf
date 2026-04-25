terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

provider "digitalocean" {
  token = var.do_token
}

data "digitalocean_ssh_key" "main" {
  name = var.ssh_key_name
}

resource "digitalocean_droplet" "lab" {
  count     = var.droplet_count
  name      = "${var.droplet_name}-${count.index + 1}"
  region    = var.region
  size      = "s-4vcpu-8gb"
  image     = "ubuntu-22-04-x64"
  ssh_keys  = [data.digitalocean_ssh_key.main.id]
  user_data = file("${path.module}/cloud-init.yaml")

  tags = ["lab", "terraform"]
}
