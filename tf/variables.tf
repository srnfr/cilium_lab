variable "do_token" {
  type        = string
  sensitive   = true
}

variable "ssh_key_name" {
  type        = string
  default     = "3274777"
}

variable "region" {
  type        = string
  default     = "ams3"   # Amsterdam — changer selon besoin
}


variable "droplet_name" {
  type        = string
  default     = "cilium_lab"
}

variable "droplet_count" {
  description = "Nombre de Droplets à créer"
  type        = number
  default     = 1
}
