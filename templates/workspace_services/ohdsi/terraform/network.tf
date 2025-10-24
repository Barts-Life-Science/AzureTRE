resource "azurerm_private_endpoint" "synapse_pe_workspace" {
  count               = local.is_synapse_data_source ? 1 : 0
  name                = "pe-synapse-ws-${local.service_suffix}"
  location            = data.azurerm_resource_group.ws.location
  resource_group_name = data.azurerm_resource_group.ws.name
  subnet_id           = data.azurerm_subnet.services.id
  tags                = local.tre_workspace_service_tags

  private_service_connection {
    name                           = "psc-synapse-ws-${local.service_suffix}"
    private_connection_resource_id = "/subscriptions/${local.synapse_subscription_id}/resourceGroups/${local.synapse_resource_group}/providers/Microsoft.Synapse/workspaces/${local.synapse_workspace_name}"
    subresource_names              = ["Sql"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [data.azurerm_private_dns_zone.synapse_sql[0].id]
  }

  depends_on = [
    data.azurerm_private_dns_zone.synapse_sql
  ]

  lifecycle { ignore_changes = [tags] }
}

resource "azurerm_private_endpoint" "synapse_pe_core" {
  count               = local.is_synapse_data_source ? 1 : 0
  name                = "pe-synapse-core-${local.service_suffix}"
  location            = data.azurerm_resource_group.ws.location
  resource_group_name = data.azurerm_resource_group.ws.name
  subnet_id           = data.azurerm_subnet.resource_processor.id
  tags                = local.tre_workspace_service_tags

  private_service_connection {
    name                           = "psc-synapse-core-${local.service_suffix}"
    private_connection_resource_id = "/subscriptions/${local.synapse_subscription_id}/resourceGroups/${local.synapse_resource_group}/providers/Microsoft.Synapse/workspaces/${local.synapse_workspace_name}"
    subresource_names              = ["Sql"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [data.azurerm_private_dns_zone.synapse_sql[0].id]
  }

  depends_on = [
    data.azurerm_private_dns_zone.synapse_sql
  ]

  lifecycle { ignore_changes = [tags] }
}

resource "azurerm_private_dns_a_record" "synapse_sql" {
  count               = local.is_synapse_data_source ? 1 : 0
  name                = "${local.synapse_workspace_name}-${local.service_suffix}"
  zone_name           = data.azurerm_private_dns_zone.synapse_sql[0].name
  resource_group_name = data.azurerm_private_dns_zone.synapse_sql[0].resource_group_name
  ttl                 = 300
  records             = [azurerm_private_endpoint.synapse_pe_workspace[0].private_service_connection[0].private_ip_address]

  depends_on = [
    data.azurerm_private_dns_zone.synapse_sql
  ]
}

# TODO TW: Remove this from here, it's going to the core
# resource "azurerm_private_dns_zone_virtual_network_link" "postgres_core_vnet_link" {
#   count                 = local.is_synapse_data_source ? 1 : 0
#   name                  = "postgres-core-vnet-link"
#   resource_group_name   = local.core_resource_group_name
#   private_dns_zone_name = data.azurerm_private_dns_zone.postgres.name
#   virtual_network_id    = data.azurerm_virtual_network.core.id
#   registration_enabled  = false
# }

# TODO TW: Remove this from here, it's going to the core
# resource "azurerm_private_dns_zone_virtual_network_link" "synapse_sql_core_vnet_link" {
#   count                 = local.is_synapse_data_source ? 1 : 0
#   name                  = "synapse-sql-core-vnet-link"
#   resource_group_name   = local.core_resource_group_name
#   private_dns_zone_name = data.azurerm_private_dns_zone.synapse_sql[0].name
#   virtual_network_id    = data.azurerm_virtual_network.core.id
#   registration_enabled  = false
# }
