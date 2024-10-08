locals {
  # This is not DRY! See the network module.
  core_services_vnet_subnets         = cidrsubnets(var.core_address_space, 4, 4, 4, 4, 2, 4, 4, 4, 4, 4, 4, 4, 4)
  dns_resolver_subnet_address_prefix = local.core_services_vnet_subnets[11] # .128 - .191

  tre_core_tags = {
    tre_id              = var.tre_id
    tre_core_service_id = var.tre_id
  }
}
