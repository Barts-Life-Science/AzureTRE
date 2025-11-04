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

# TODO: TW - Feels like I'm going in circles here. Will this work? Is it tre-unique, or w/s-unique?
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

