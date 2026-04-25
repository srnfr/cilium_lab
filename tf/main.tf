
variable "ssh_keys" {
  default = []
}

variable "droplet_image" {
  type        = string
}

variable "droplet_name" {
  type        = string
}

variable "droplet_count" {
  type        = string
}

variable "region" {
  type        = string
}

variable "droplet_size" {
  type        = string
}

variable "root_password" {
  description = "Mot de passe root SSH"
  type        = string
  sensitive   = true   # masqué dans les logs Terraform Cloud
}

resource "digitalocean_droplet" "cilium-lab" {
  count     = var.droplet_count
  name      = "${var.droplet_name}-${count.index + 1}"
  region    = var.region
  size      = var.droplet_size
  image     = var.droplet_image
  ssh_keys  = var.ssh_keys
  ##user_data = "${file("cloud-init.yaml")}"

  user_data = templatefile("${path.module}/cloud-init.yaml.tpl", {
    root_password = var.root_password
  })
  tags = ["lab", "terraform"]
}
