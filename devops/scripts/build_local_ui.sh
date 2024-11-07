#!/bin/bash
set -o errexit
set -o pipefail
set -o nounset

# Get the directory that this script is in
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

pushd "$DIR/../../ui/app"

ui_version=$(jq -r '.version' package.json)

# Set default values for local development
LOCAL_CLIENT_ID="${LOCAL_CLIENT_ID:-local-client-id}"
LOCAL_TENANT_ID="${LOCAL_TENANT_ID:-local-tenant-id}"
LOCAL_API_CLIENT_ID="${LOCAL_API_CLIENT_ID:-api-client-id}"
LOCAL_TRE_ID="${LOCAL_TRE_ID:-local-tre}"
LOCAL_API_URL="${LOCAL_API_URL:-http://localhost:8000/api}"

# For local development, we'll use the public Azure AD endpoint
LOCAL_AD_URI="https://login.microsoftonline.com"

# replace the values in the config file
jq --arg rootClientId "${LOCAL_CLIENT_ID}" \
  --arg rootTenantId "${LOCAL_TENANT_ID}" \
  --arg treApplicationId "api://${LOCAL_API_CLIENT_ID}" \
  --arg treUrl "${LOCAL_API_URL}" \
  --arg treId "${LOCAL_TRE_ID}" \
  --arg version "${ui_version}" \
  --arg activeDirectoryUri "${LOCAL_AD_URI}" \
  '.rootClientId = $rootClientId | .rootTenantId = $rootTenantId | .treApplicationId = $treApplicationId | .treUrl = $treUrl | .treId = $treId | .version = $version | .activeDirectoryUri = $activeDirectoryUri' ./src/config.source.json > ./src/config.json

# Install dependencies and start development server
echo "Installing dependencies..."
yarn install

echo "Starting development server..."
yarn start

popd
