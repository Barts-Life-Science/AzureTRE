# Grant the VM's system-assigned managed identity data-plane access to the
# workspace shared storage account. With this in place, researchers on the VM
# can authenticate to blob storage with `az login --identity` (no per-user
# credentials, no Conditional Access on user grant types) and read/write any
# container on the workspace SA — including the long-term "archive" container
# with its lifecycle policy.
resource "azurerm_role_assignment" "vm_storage_blob_data_contributor" {
  count                = tobool(var.shared_storage_access) ? 1 : 0
  scope                = data.azurerm_storage_account.stg.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_linux_virtual_machine.linuxvm.identity[0].principal_id
}
