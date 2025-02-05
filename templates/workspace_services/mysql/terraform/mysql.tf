resource "random_password" "password" {
  length      = 20
  min_upper   = 2
  min_lower   = 2
  min_numeric = 2
  min_special = 2
}

resource "azurerm_mysql_flexible_server" "mysql" {
  name                         = "mysql-${local.service_resource_name_suffix}"
  resource_group_name          = data.azurerm_resource_group.ws.name
  location                     = data.azurerm_resource_group.ws.location
  administrator_login          = "mysqladmin"
  administrator_password       = random_password.password.result
  sku_name                     = local.sql_sku[var.sql_sku].value
  version                      = "8.0.21"
  backup_retention_days        = 7
  geo_redundant_backup_enabled = false
  tags                         = local.workspace_service_tags

  lifecycle { ignore_changes = [tags, zone] }
}

resource "azurerm_mysql_flexible_database" "db" {
  name                = var.db_name
  resource_group_name = data.azurerm_resource_group.ws.name
  server_name         = azurerm_mysql_flexible_server.mysql.name
  charset             = "utf8"
  collation           = "utf8_unicode_ci"

  lifecycle { ignore_changes = [charset, collation] }
}

resource "azurerm_private_endpoint" "mysql_private_endpoint" {
  name                = "pe-${azurerm_mysql_flexible_server.mysql.name}"
  location            = data.azurerm_resource_group.ws.location
  resource_group_name = data.azurerm_resource_group.ws.name
  subnet_id           = data.azurerm_subnet.services.id
  tags                = local.workspace_service_tags

  private_service_connection {
    private_connection_resource_id = azurerm_mysql_flexible_server.mysql.id
    name                           = "psc-${azurerm_mysql_flexible_server.mysql.name}"
    subresource_names              = ["mysqlServer"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = module.terraform_azurerm_environment_configuration.private_links["privatelink.mysql.database.azure.com"]
    private_dns_zone_ids = [data.azurerm_private_dns_zone.mysql.id]
  }

  lifecycle { ignore_changes = [tags] }
}

resource "azurerm_key_vault_secret" "db_password" {
  name         = "${azurerm_mysql_flexible_server.mysql.name}-administrator-password"
  value        = random_password.password.result
  key_vault_id = data.azurerm_key_vault.ws.id
  tags         = local.workspace_service_tags

  lifecycle { ignore_changes = [tags] }
}

data "azurerm_data_factory" "adf_core" {
  name                = "adf-${var.tre_id}"
  resource_group_name = "rg-${var.tre_id}"
}

# Create a private endpoint to the MySQL server from the data platform
resource "azurerm_data_factory_managed_private_endpoint" "adf_mysql_pe" {
  name               = "pe-adf-mysql-${local.workspace_resource_name_suffix}"
  data_factory_id    = data.azurerm_data_factory.adf_core.id
  target_resource_id = azurerm_mysql_flexible_server.mysql.id
  subresource_name   = "mysqlServer"
}

resource "null_resource" "approve_private_endpoint" {
  provisioner "local-exec" {
    command = "sh approve_pe.sh '${data.azurerm_resource_group.ws.name}' '${azurerm_mysql_flexible_server.mysql.name}' '${local.workspace_resource_name_suffix}' '${var.arm_client_id}' '${var.arm_subscription_id}'"
  }
  depends_on = [azurerm_data_factory_managed_private_endpoint.adf_mysql_pe]
}

# Create a linked service in the data factory to the MySQL server
resource "azurerm_data_factory_linked_service_mysql" "ls_mysql" {
  name                     = "ls-adf-mysql-${local.workspace_resource_name_suffix}"
  data_factory_id          = data.azurerm_data_factory.adf_core.id
  connection_string        = "Server=${"${azurerm_mysql_flexible_server.mysql.name}.mysql.database.azure.com"};Port=3306;Database=${var.db_name};Uid=${"${azurerm_mysql_flexible_server.mysql.name}-administrator-password"};Pwd=${random_password.password.result};"
  integration_runtime_name = "adf-ir-${var.tre_id}"
}
