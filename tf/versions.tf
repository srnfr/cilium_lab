terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }
}

variable "do_token" {}

provider "digitalocean" {
  token = var.do_token
  ## TO BE DEFINED IN VARIABLES SETTINGS OF THE TERRAFORM WORSKPACE, AS do_token
}

variable "cloudflare_api_token" {
  type        = string
  sensitive   = true
  description = "Cloudflare API token with zone read and DNS edit permissions. Set as a sensitive Terraform Cloud variable."
}

variable "cloudflare_zone_id" {
  type        = string
  description = "Cloudflare zone ID for the DNS zone managed by this workspace."
}

variable "dns_zone_name" {
  type        = string
  description = "DNS zone name supplied by Terraform Cloud, for example the managed domain without a trailing dot."
}

variable "dns_record_prefix" {
  type        = string
  default     = "vm"
  description = "Prefix used for Droplet DNS records."
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
