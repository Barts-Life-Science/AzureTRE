#!/bin/bash

# This script installs the Azure CLI on a Debian-based system.
#
# Key functionalities include:
# - Updating the package list to ensure the latest package information.
# - Installing necessary dependencies such as ca-certificates, curl, and gnupg.
# - Adding the Microsoft package signing key to the list of trusted keys.
# - Configuring the Azure CLI package repository based on the system's release code name.
# - Installing a specific version of the Azure CLI.
#

set -o errexit
set -o pipefail
set -o nounset
# Uncomment this line to see each command for debugging (careful: this will show secrets!)
# set -o xtrace

# Install Azure CLI
apt-get update
apt-get -y install ca-certificates curl apt-transport-https lsb-release gnupg
curl -sL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | tee /etc/apt/trusted.gpg.d/microsoft.gpg > /dev/null
AZ_REPO="$(lsb_release -cs)"
echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" | tee /etc/apt/sources.list.d/azure-cli.list
apt-get update
apt-get -y install azure-cli="${AZURE_CLI_VERSION}"
