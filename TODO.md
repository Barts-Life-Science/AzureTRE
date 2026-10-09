# TODO

## Gitea workspace service: disable public network access

The Gitea workspace service web app (`templates/workspace_services/gitea/terraform/gitea-webapp.tf`) is reachable from the public internet: a private endpoint alone does not block public access to an App Service. It needs `public_network_access_enabled = false`, as upstream added in [microsoft/AzureTRE#4559](https://github.com/microsoft/AzureTRE/pull/4559).

That argument is not supported by the template's pinned provider (`azurerm = "=3.22.0"`; Terraform validation fails with `Unsupported argument`), so the fix needs a provider upgrade first. Upstream is on `azurerm 4.27.0` and Gitea workspace service 1.3.2 (ours: 1.0.3), so syncing the template from upstream may be simpler than a hand upgrade.

While upgrading, also align with the Gitea shared service:

- `minimum_tls_version` is `"1.2"` here, `"1.3"` in the shared service
- add `ftp_publish_basic_authentication_enabled = false` and `webdeploy_publish_basic_authentication_enabled = false`
- replace the deprecated `dynamic "log"` diagnostic block with `dynamic "enabled_log"`

Not currently deployed anywhere (as of 2026-10-09). Fix before deploying it.
