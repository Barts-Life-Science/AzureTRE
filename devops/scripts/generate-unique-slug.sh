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

#
# Be paranoid about creating zombie groups: Check to see if a group already
# exists with the current name, and abort if that's the case.
here=$(dirname $0)
config_file="${here}/../../config.yaml"
mgmt_group=$(yq .management.mgmt_resource_group_name ${config_file})
if [ "${mgmt_group}" != "__THIS_IS_SET_AUTOMATICALLY__" ]; then
  exists=$(az group list --query "[?name=='${mgmt_group}'].name" --output tsv)
  if [ "${exists}" == "${mgmt_group}" ]; then
    echo "A previously configured managment group exists with the name \"${mgmt_group}\""
    echo "Delete this group before continuing, or you risk having zombie infrastructure"
    exit 1
  fi
fi
printf -v slug "%x" "$(date +%s)"

echo "Updating config file with TRE slug ${slug}"
yq --inplace \
  e " \
      .management.mgmt_resource_group_name = .tre_id + \"-${slug}\" \
    " \
    "${config_file}"
