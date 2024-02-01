#!/bin/bash
set -o pipefail
set -o errexit
set -o nounset
# set -o xtrace

#
# Generate a unique name for the management resource group, based on the TRE_ID
# and the epoch time in seconds. Then, to start a fresh deployment, just
# generate a new slug with the 'make slug' command. This gets round the problem
# of soft-deleting resources, such as the key vault and various bits of logging.
#
here=$(dirname $0)
config_file="${here}/../../config.yaml"

#
# Be paranoid about creating zombie infrastructure:
# Check to see if a keyvault already exists with the current name,
# and abort if that's the case.
slug=$(yq '.management.slug // ""' ${config_file})
mgmt_group=$(yq .management.mgmt_resource_group_name ${config_file})
kv_name="kv-${mgmt_group}${slug}"

kv_exists=$(az keyvault list --resource-group rg-aztre --query "[?name=='${kv_name}'].name" --output tsv)
if [ "${kv_exists}" == "${kv_name}" ]; then
  echo "A previously configured keyvault exists with the name \"${kv_name}\""
  echo "Delete this keyvault before continuing, or you risk having zombie infrastructure"
  exit 1
fi

#
# No active keyvault with the expected name, so I can go ahead and create the slug
printf -v slug "%x" "$(date +%s)"
echo "Updating config file with slug ${slug}"
yq --inplace e ".management.slug = \"-${slug}\"" "${config_file}"
