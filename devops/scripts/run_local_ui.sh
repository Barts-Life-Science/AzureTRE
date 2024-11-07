#!/bin/bash
set -o errexit
set -o pipefail
set -o nounset

# Get the directory that this script is in
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Read values from config.yaml using yq (make sure yq is installed)
CONFIG_FILE="$DIR/../../config.yaml"

# Extract values from config.yaml
export LOCAL_TENANT_ID=$(yq '.authentication.aad_tenant_id' "$CONFIG_FILE")
export LOCAL_CLIENT_ID=$(yq '.authentication.swagger_ui_client_id' "$CONFIG_FILE")
export LOCAL_API_CLIENT_ID=$(yq '.authentication.api_client_id' "$CONFIG_FILE")
export LOCAL_TRE_ID=$(yq '.tre_id' "$CONFIG_FILE")

# Set the API URL for local development
export LOCAL_API_URL="http://localhost:8000/api"

echo "Using the following configuration:"
echo "Tenant ID: $LOCAL_TENANT_ID"
echo "Client ID: $LOCAL_CLIENT_ID"
echo "API Client ID: $LOCAL_API_CLIENT_ID"
echo "TRE ID: $LOCAL_TRE_ID"
echo "API URL: $LOCAL_API_URL"

# Run the local UI build script
"$DIR/build_local_ui.sh"
