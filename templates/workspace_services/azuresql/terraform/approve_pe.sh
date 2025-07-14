#!/bin/bash

# Log commands and exit on errors
set -ex

# Assuming command line arguments for simplicity
rg_name=$1
sql_server_name=$2
private_endpoint_name=$3
arm_client_id=$4
arm_subscription_id=$5
data_factory_name=$6

# Login using the Managed Identity
az login --identity --client-id "$arm_client_id"

# Get the name of the private-endpoint-connection
name=$(az network private-endpoint-connection list \
  --id "/subscriptions/${arm_subscription_id}/resourceGroups/${rg_name}/providers/Microsoft.Sql/servers/${sql_server_name}" \
  --output json | jq -r \
  --arg suffix "privateEndpoints/${data_factory_name}.${private_endpoint_name}" \
  '.[]
   | select(.properties.privateLinkServiceConnectionState.status == "Pending")
   | select(.properties.privateEndpoint.id | endswith($suffix))
   | .name')

# Exit if name not found
if [ -z "$name" ]; then
    echo "No pending private endpoint connection found."
    exit 1
fi

#Approve the private-endpoint-connection
az network private-endpoint-connection approve \
  -g "$rg_name" \
  -n "$name" \
  --resource-name "$sql_server_name" \
  --type "Microsoft.Sql/servers" \
  --description "Auto-Approved by custom script."
