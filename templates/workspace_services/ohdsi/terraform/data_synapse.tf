data "azurerm_client_config" "current" {}

# data "azurerm_synapse_workspace" "synapse_cdm" {
#   count               = local.is_synapse_data_source && local.synapse_workspace_name != null ? 1 : 0
#   name                = local.synapse_workspace_name
#   resource_group_name = local.synapse_resource_group
# }
