
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

resource "digitalocean_droplet" "cilium_lab" {
  count     = var.droplet_count
  name      = "${var.droplet_name}-${count.index + 1}"
  region    = var.region
  size      = var.droplet_size
  image     = var.droplet_image
  ssh_keys  = var.ssh_keys
  user_data = "${file("cloud-init.yaml")}"

  tags = ["lab", "terraform"]
}
