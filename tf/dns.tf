locals {
  droplet_ipv4_addresses = {
    for index, droplet in digitalocean_droplet.cilium-lab :
    tostring(index) => droplet.ipv4_address
  }
}

resource "cloudflare_dns_record" "droplet" {
  for_each = local.droplet_ipv4_addresses

  zone_id = var.cloudflare_zone_id
  name    = "${var.dns_record_prefix}-${each.key}.${var.dns_zone_name}"
  type    = "A"
  content = each.value
  ttl     = 1
  proxied = false
}
