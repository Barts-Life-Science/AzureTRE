resource "random_password" "password" {
  length      = 20
  min_upper   = 2
  min_lower   = 2
  min_numeric = 2
  min_special = 2
}

resource "azurerm_mssql_server" "azuresql" {
  name                                 = local.azuresql_server_name
  resource_group_name                  = data.azurerm_resource_group.ws.name
  location                             = data.azurerm_resource_group.ws.location
  version                              = "12.0"
  administrator_login                  = local.azuresql_administrator_login
  administrator_login_password         = random_password.password.result
  minimum_tls_version                  = "1.2"
  public_network_access_enabled        = false
  outbound_network_restriction_enabled = true
  tags                                 = local.workspace_service_tags

  lifecycle { ignore_changes = [tags] }
}

resource "azurerm_mssql_database" "azuresqldatabase" {
  name         = var.db_name
  server_id    = azurerm_mssql_server.azuresql.id
  collation    = local.azuresql_collation
  license_type = "LicenseIncluded"
  max_size_gb  = var.storage_gb
  sku_name     = local.azuresql_sku[var.sql_sku].value
  tags         = local.workspace_service_tags

  lifecycle { ignore_changes = [tags] }
}

resource "azurerm_private_endpoint" "azuresql_private_endpoint" {
  name                = local.azuresql_private_endpoint_name
  location            = data.azurerm_resource_group.ws.location
  resource_group_name = data.azurerm_resource_group.ws.name
  subnet_id           = data.azurerm_subnet.services.id
  tags                = local.workspace_service_tags

  private_service_connection {
    private_connection_resource_id = azurerm_mssql_server.azuresql.id
    name                           = local.azuresql_private_service_connection_name
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = module.terraform_azurerm_environment_configuration.private_links["privatelink.database.windows.net"]
    private_dns_zone_ids = [data.azurerm_private_dns_zone.azuresql.id]
  }

  lifecycle { ignore_changes = [tags] }
}

resource "azurerm_key_vault_secret" "db_password" {
  name         = local.azuresql_password_keyvault_secret_name
  value        = random_password.password.result
  key_vault_id = data.azurerm_key_vault.ws.id
  tags         = local.workspace_service_tags

  lifecycle { ignore_changes = [tags] }
}

data "azurerm_data_factory" "adf_core" {
  name                = "adf-sdebeta"
  resource_group_name = "rg-sdebeta"
}

resource "azurerm_data_factory_linked_service_azure_sql_database" "ls_azsql" {
  name                     = "adf-prod-azsql-${local.workspace_resource_name_suffix}"
  data_factory_id          = data.azurerm_data_factory.adf_core.id
  integration_runtime_name = "adf-ir-sdebeta"
  connection_string        = "data source=${azurerm_mssql_server.azuresql.name}.privatelink.database.windows.net;initial catalog=${azurerm_mssql_database.azuresqldatabase.name};user id=${azurerm_mssql_server.azuresql.administrator_login};Password=${azurerm_mssql_server.azuresql.administrator_login_password};integrated security=False;encrypt=True;connection timeout=30"
}

resource "azurerm_data_factory_managed_private_endpoint" "azsqlpe" {
  name               = "adf-sql-private-endpoint-${azurerm_mssql_database.azuresqldatabase.name}"
  data_factory_id    = data.azurerm_data_factory.adf_core.id
  target_resource_id = azurerm_mssql_server.azuresql.id
  subresource_name   = "sqlServer"
}

resource "null_resource" "approve_private_endpoint" {
  provisioner "local-exec" {
    command = "sh approve_pe.sh '${data.azurerm_resource_group.ws.name}' '${azurerm_data_factory_managed_private_endpoint.azsqlpe.name}' '${local.azuresql_password_keyvault_secret_name}' '${var.arm_client_id}' '${var.arm_subscription_id}'"
  }
  depends_on = [azurerm_data_factory_managed_private_endpoint.azsqlpe]
}