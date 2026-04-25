#variable "do_token" {
#  type        = string
#  sensitive   = true
#}

ssh_keys = [ "3274777" ]

region_name = "ams3"
# Droplet size
##droplet_size = "s-1vcpu-2gb"
droplet_size = "s-4vcpu-8gb-amd"
##droplet_size = "s-2vcpu-2gb"
droplet_image = "ubuntu-22-04-x64"

variable "droplet_name" {
  type        = string
  default     = "cilium_lab"
}

variable "droplet_count" {
  description = "Nombre de Droplets à créer"
  type        = number
  default     = 1
}
