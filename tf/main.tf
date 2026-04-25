
variable "ssh_keys" {
  default = []
}

variable "droplet_image" {
  type        = string
}

resource "digitalocean_droplet" "lab" {
  count     = var.droplet_count
  name      = "${var.droplet_name}-${count.index + 1}"
  region    = var.region
  size      = "s-4vcpu-8gb"
  image     = var.droplet_image
  ssh_keys  = var.ssh_keys
  user_data = "${file("cloud-init.yaml")}"

  tags = ["lab", "terraform"]
}
