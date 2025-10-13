resource "azurerm_private_endpoint" "synapse_pe_workspace" {
  count               = local.is_synapse_data_source ? 1 : 0
  name                = "pe-synapse-ws-${local.service_suffix}"
  location            = data.azurerm_resource_group.ws.location
  resource_group_name = data.azurerm_resource_group.ws.name
  subnet_id           = data.azurerm_subnet.services.id

  private_service_connection {
    name                           = "psc-synapse-ws-${local.service_suffix}"
    private_connection_resource_id = "/subscriptions/${local.synapse_subscription_id}/resourceGroups/${local.synapse_resource_group}/providers/Microsoft.Synapse/workspaces/${local.synapse_workspace_name}"
    subresource_names              = ["Sql"]
    is_manual_connection           = false
  }
}

resource "azurerm_private_endpoint" "synapse_pe_core" {
  count               = local.is_synapse_data_source ? 1 : 0
  name                = "pe-synapse-core-${local.service_suffix}"
  location            = data.azurerm_resource_group.ws.location
  resource_group_name = data.azurerm_resource_group.ws.name
  subnet_id           = data.azurerm_subnet.resource_processor.id

  private_service_connection {
    name                           = "psc-synapse-core-${local.service_suffix}"
    private_connection_resource_id = "/subscriptions/${local.synapse_subscription_id}/resourceGroups/${local.synapse_resource_group}/providers/Microsoft.Synapse/workspaces/${local.synapse_workspace_name}"
    subresource_names              = ["Sql"]
    is_manual_connection           = false
  }
}

resource "azurerm_private_dns_zone" "synapse_sql" {
  count               = local.is_synapse_data_source ? 1 : 0
  name                = "privatelink.sql.azuresynapse.net"
  resource_group_name = data.azurerm_resource_group.ws.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "synapse_sql_link" {
  count                 = local.is_synapse_data_source ? 1 : 0
  name                  = "synapse-sql-dns-link-ohdsi-omop-${local.service_suffix}"
  resource_group_name   = data.azurerm_resource_group.ws.name
  private_dns_zone_name = azurerm_private_dns_zone.synapse_sql[0].name
  virtual_network_id    = data.azurerm_virtual_network.core.id
  registration_enabled  = false
}

resource "azurerm_private_dns_a_record" "synapse_sql" {
  count               = local.is_synapse_data_source ? 1 : 0
  name                = local.synapse_workspace_name
  zone_name           = azurerm_private_dns_zone.synapse_sql[0].name
  resource_group_name = data.azurerm_resource_group.ws.name
  ttl                 = 300
  records             = [azurerm_private_endpoint.synapse_pe_workspace[0].private_service_connection[0].private_ip_address]
}
