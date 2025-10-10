data "azurerm_synapse_workspace" "synapse_cdm" {
  name                = local.synapse_workspace_name        # "synapse-ws-omop-ohdsi-test"
  resource_group_name = local.synapse_resource_group        # "rg-omop-ohdsi-test"
}
