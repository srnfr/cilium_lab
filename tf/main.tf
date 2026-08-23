
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
  type        = string
}

variable "ghrepo" {
  type        = string
}

variable "digitalocean_project_name" {
  type        = string
  default     = "LAB"
  description = "Existing DigitalOcean project receiving the Droplets."
}

resource "digitalocean_droplet" "cilium-lab" {
  count     = var.droplet_count
  name      = "${var.droplet_name}-${count.index}"
  region    = var.region
  size      = var.droplet_size
  image     = var.droplet_image
  ssh_keys  = var.ssh_keys
  ##user_data = "${file("cloud-init.yaml")}"

  user_data = templatefile("${path.module}/cloud-init.yaml.tpl", {
    root_password = var.root_password, ghrepo = var.ghrepo
  })
}

data "digitalocean_project" "lab" {
  name = var.digitalocean_project_name
}

resource "digitalocean_project_resources" "cilium_lab" {
  project = data.digitalocean_project.lab.id
  resources = [
    for droplet in digitalocean_droplet.cilium-lab : droplet.urn
  ]
}
