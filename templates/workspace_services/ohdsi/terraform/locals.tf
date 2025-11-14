locals {
  short_service_id               = substr(var.tre_resource_id, -4, -1)
  short_workspace_id             = substr(var.workspace_id, -4, -1)
  workspace_resource_name_suffix = "${var.tre_id}-ws-${local.short_workspace_id}"
  core_resource_group_name       = "rg-${var.tre_id}"
  service_suffix                 = "${local.workspace_resource_name_suffix}-svc-${local.short_service_id}"
  key_vault_name                 = lower("kv-${substr(local.workspace_resource_name_suffix, -20, -1)}")
  storage_name                   = lower(replace("stg${substr(local.workspace_resource_name_suffix, -8, -1)}", "-", ""))
  porter_yaml                    = yamldecode(file("${path.module}/../porter.yaml"))

  # ATLAS Database
  postgres_admin_username        = "postgres_admin"
  postgres_webapi_admin_username = "ohdsi_admin_user"
  postgres_webapi_admin_role     = "ohdsi_admin"
  postgres_webapi_app_username   = "ohdsi_app_user"
  postgres_webapi_app_role       = "ohdsi_app"
  postgres_webapi_database_name  = "atlas_webapi_db"
  postgres_schema_name           = "webapi"
  postgres_version               = "14"
  postgres_server_log_analytics_categories = [
    "PostgreSQLLogs"
  ]

  # ATLAS UI
  atlas_ui_name               = "app-ohdsi-atlas-${local.service_suffix}"
  atlas_ui_fqdn               = "${local.atlas_ui_name}.${module.terraform_azurerm_environment_configuration.web_app_suffix}"
  atlas_ui_url                = "https://${local.atlas_ui_fqdn}/atlas"
  atlas_ui_url_welcome        = "${local.atlas_ui_url}/#/welcome"
  atlas_ui_storage_share_name = "atlas-${local.service_suffix}"
  atlas_ui_mount_path         = "/etc/atlas"
  atlas_ui_docker_image_name  = "ohdsi/atlas"
  atlas_ui_docker_image_tag   = "2.14.0" # +2.12.1, 2.13.0, +2.14.0, -2.15.0
  config_local_file_path      = "/tmp/config-local.js"
  atals_ui_log_analytics_categories = [
    "AppServiceAppLogs",
    "AppServiceConsoleLogs",
    "AppServiceHTTPLogs"
  ]

# 2.14.0 works with the old flyway.
# 2.15.0 doesn't seem to work. Try 2.15.0 + 2.15.1
  # OHDSI WEB API
  ohdsi_webapi_name                 = "app-ohdsi-webapi-${local.service_suffix}"
  ohdsi_webapi_fqdn                 = "${local.ohdsi_webapi_name}.${module.terraform_azurerm_environment_configuration.web_app_suffix}"
  ohdsi_webapi_url                  = "https://${local.ohdsi_webapi_fqdn}/WebAPI/"
  ohdsi_webapi_url_auth_callback    = "${local.ohdsi_webapi_url}user/oauth/callback"
  ohdsi_api_docker_image_name       = "ohdsi/webapi"
  ohdsi_api_docker_image_tag        = "2.14.0" # +2.12.1, 2.13.0, +2.14.0, -2.15.0, -2.15.1
  ohdsi_api_flyway_baseline_version = "2.2.5.20180212152023" # "2.9.0.20210812164224" # for 2.15.0 # for 2.12.1 "2.2.5.20180212152023". ALso works for 2.14.0
  ohdsi_api_log_analytics_categories = [
    "AppServiceAppLogs",
    "AppServiceConsoleLogs",
    "AppServiceHTTPLogs"
  ]

  tre_workspace_service_tags = {
    tre_id                   = var.tre_id
    tre_workspace_id         = var.workspace_id
    tre_workspace_service_id = var.tre_resource_id
  }

  # Data Source configuration
  dialects               = local.porter_yaml["custom"]["dialects"]
  data_source_config     = try(jsondecode(base64decode(var.data_source_config)), {})
  data_source_daimons    = try(jsondecode(base64decode(var.data_source_daimons)), {})
  data_source_dialect    = try(local.data_source_config.dialect, null)
  is_synapse_data_source = var.configure_data_source && local.data_source_dialect == "Azure Synapse"
  daimon_results         = try(local.data_source_daimons.daimon_results, null)
  daimon_temp            = try(local.data_source_daimons.daimon_temp, null)
  results_schema_name    = local.is_synapse_data_source && local.daimon_results != null ? "${local.data_source_daimons.daimon_results}_${replace(var.tre_resource_id, "-", "_")}" : local.daimon_results
  temp_schema_name       = local.is_synapse_data_source && local.daimon_temp != null ? "${local.data_source_daimons.daimon_temp}_${replace(var.tre_resource_id, "-", "_")}" : local.daimon_temp

  # Synapse Workspace - extract from data source config
  synapse_workspace_name   = try(local.data_source_config.synapse_workspace_name, null)
  synapse_resource_group   = try(local.data_source_config.synapse_resource_group, null)
  synapse_database_name    = try(local.data_source_config.synapse_database_name, null)
  synapse_subscription_id  = try(local.data_source_config.synapse_subscription_id, "") != "" ? local.data_source_config.synapse_subscription_id : data.azurerm_client_config.current.subscription_id

  # Build connection string automatically for Synapse
  synapse_connection_string = local.is_synapse_data_source && local.synapse_workspace_name != null && local.synapse_database_name != null ? (
    "jdbc:sqlserver://${local.synapse_workspace_name}.privatelink.sql.azuresynapse.net:1433;database=${local.synapse_database_name};encrypt=true;trustServerCertificate=false;hostNameInCertificate=*.sql.azuresynapse.net;loginTimeout=30"
  ) : null

  # Use provided connection string or the derived one
  final_connection_string = try(local.data_source_config.connection_string, null) != null && try(local.data_source_config.connection_string, "") != "" ? local.data_source_config.connection_string : local.synapse_connection_string
}
