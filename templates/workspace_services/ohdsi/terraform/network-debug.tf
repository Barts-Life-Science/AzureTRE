# ###############################################################################
# # Extra PE so that VMs sitting in ServicesSubnet can reach Synapse privately  #
# # Enable this for debugging, but not for production use.                      #
# ###############################################################################

# resource "azurerm_private_endpoint" "synapse_pe_services" {
#   # Only build it when the template is configured for Synapse
#   count               = local.is_synapse_data_source ? 1 : 0

#   name                = "pe-synapse-svc-${local.service_suffix}"
#   location            = data.azurerm_resource_group.ws.location
#   resource_group_name = data.azurerm_resource_group.ws.name
#   subnet_id           = data.azurerm_subnet.services.id          # <-- ServicesSubnet
#   tags                = local.tre_workspace_service_tags

#   private_service_connection {
#     name                           = "psc-synapse-svc-${local.service_suffix}"
#     private_connection_resource_id = "/subscriptions/${local.synapse_subscription_id}/resourceGroups/${local.synapse_resource_group}/providers/Microsoft.Synapse/workspaces/${local.synapse_workspace_name}"
#     subresource_names              = ["Sql"]
#     is_manual_connection           = false
#   }

#   # Wire the endpoint into the same private-DNS zone so hosts in the VNet
#   # resolve *.privatelink.sql.azuresynapse.net to the new PE address.
#   private_dns_zone_group {
#     name                 = "default"
#     private_dns_zone_ids = [azurerm_private_dns_zone.synapse_sql[0].id]
#   }

#   lifecycle { ignore_changes = [tags] }
# }

# ###############################################################################
# # Link the workspace VNet itself to the private DNS zone (optional but handy) #
# ###############################################################################

# resource "azurerm_private_dns_zone_virtual_network_link" "synapse_sql_ws_link" {
#   count                 = local.is_synapse_data_source ? 1 : 0

#   name                  = "synapse-sql-dns-link-ws-${local.service_suffix}"
#   resource_group_name   = data.azurerm_resource_group.ws.name
#   private_dns_zone_name = azurerm_private_dns_zone.synapse_sql[0].name
#   virtual_network_id    = data.azurerm_virtual_network.ws.id      # <-- workspace VNet
#   registration_enabled  = false
# }
