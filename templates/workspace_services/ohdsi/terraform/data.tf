data "azurerm_resource_group" "ws" {
  name = "rg-${var.tre_id}-ws-${local.short_workspace_id}"
}

data "azurerm_key_vault" "ws" {
  name                = local.key_vault_name
  resource_group_name = data.azurerm_resource_group.ws.name
}

data "azurerm_key_vault_secret" "aad_tenant_id" {
  name         = "auth-tenant-id"
  key_vault_id = data.azurerm_key_vault.ws.id
}

data "azurerm_key_vault_secret" "workspace_client_id" {
  name         = "workspace-client-id"
  key_vault_id = data.azurerm_key_vault.ws.id
}

data "azurerm_key_vault_secret" "workspace_client_secret" {
  name         = "workspace-client-secret"
  key_vault_id = data.azurerm_key_vault.ws.id
}

data "azurerm_log_analytics_workspace" "workspace" {
  name                = "log-${var.tre_id}-ws-${local.short_workspace_id}"
  resource_group_name = data.azurerm_resource_group.ws.name
}

data "azurerm_storage_account" "stg" {
  name                = local.storage_name
  resource_group_name = data.azurerm_resource_group.ws.name
}

data "azurerm_service_plan" "workspace" {
  name                = "plan-${var.workspace_id}"
  resource_group_name = data.azurerm_resource_group.ws.name
}

data "azurerm_virtual_network" "ws" {
  name                = "vnet-${var.tre_id}-ws-${local.short_workspace_id}"
  resource_group_name = data.azurerm_resource_group.ws.name
}

data "azurerm_virtual_network" "core" {
  name                = "vnet-${var.tre_id}"
  resource_group_name = local.core_resource_group_name
}

data "azurerm_subnet" "web_app" {
  name                 = "WebAppsSubnet"
  virtual_network_name = data.azurerm_virtual_network.ws.name
  resource_group_name  = data.azurerm_resource_group.ws.name
}

data "azurerm_subnet" "services" {
  name                 = "ServicesSubnet"
  virtual_network_name = data.azurerm_virtual_network.ws.name
  resource_group_name  = data.azurerm_resource_group.ws.name
}

data "azurerm_subnet" "resource_processor" {
  name                 = "ResourceProcessorSubnet"
  resource_group_name  = local.core_resource_group_name
  virtual_network_name = data.azurerm_virtual_network.core.name
}

data "azurerm_private_dns_zone" "azurewebsites" {
  name                = module.terraform_azurerm_environment_configuration.private_links["privatelink.azurewebsites.net"]
  resource_group_name = local.core_resource_group_name
}

data "azurerm_private_dns_zone" "postgres" {
  name                = module.terraform_azurerm_environment_configuration.private_links["privatelink.postgres.database.azure.com"]
  resource_group_name = local.core_resource_group_name
}

data "azurerm_private_dns_zone" "synapse_sql" {
  count               = local.is_synapse_data_source ? 1 : 0
  name                = module.terraform_azurerm_environment_configuration.private_links["privatelink.sql.azuresynapse.net"]
  resource_group_name = local.core_resource_group_name
}

# Need this to assign the storage role to the VMSS MSI so it can upload the UI config file.
data "azuread_service_principal" "vmss_msi" {
  display_name = "id-vmss-${var.tre_id}"
}
