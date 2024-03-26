#!/usr/bin/env bash
#
# This script will set up the secrets and environment variables in a
# github environment so it can run the CI/CD pipeline.
#
# This script calls a python script to encrypt secrets. You need to install
# pynacl for that script: 'pip install pynacl'
#
# You also need to have your service-principal account created in Azure
# (see https://microsoft.github.io/AzureTRE/latest/tre-admins/environment-variables/)
#
# and you need your config.yaml to be fully configured, as described in the docs.
#
# Set the name of the owner/repository, and the github environment to work in.
# The github environment must already exist.
REPO="Barts-Life-Science/AzureTRE"
ENV="CICD"

#
# No user-configurable parts below...
#
set -o pipefail
set -o errexit

config_yaml="config.yaml"

header1="Accept: application/vnd.github+json"
header2="X-GitHub-Api-Version: 2022-11-28"

echo ' '
public_key_id=$(gh api -H "${header1}" -H "${header2}" \
  /repos/${REPO}/environments/${ENV}/secrets/public-key \
  | jq .key_id \
  | tr -d '"')
public_key=$(gh api -H "${header1}" -H "${header2}" \
  /repos/${REPO}/environments/${ENV}/secrets/public-key \
  | jq .key \
  | tr -d '"')
echo "Key=${public_key}, key_id=${public_key_id}"

function set_env_secret() {
  secret_name=$1
  secret_value=$2
  if [ "${secret_value}" == "" ]; then
    echo "Usage: $0 <secret_name> <secret_value>"
    exit 0
  fi

# echo ./gh-encrypt-string.py "${public_key}" "${secret_value}"
  encrypted_value=$(./gh-encrypt-string.py "${public_key}" "${secret_value}")
# echo "Encrypted string is '${encrypted_value}'"

  gh api -H "${header1}" -H "${header2}" \
    --method PUT \
    /repos/${REPO}/environments/${ENV}/secrets/${secret_name} \
    -f encrypted_value="${encrypted_value}" \
    -f key_id="${public_key_id}"
}

export TRE_ID=$(yq .tre_id ${config_yaml})
export ACR_NAME=$(yq .management.acr_name ${config_yaml})
export MGMT_RESOURCE_GROUP_NAME=$(yq .management.mgmt_resource_group_name ${config_yaml})
export MGMT_STORAGE_ACCOUNT_NAME=$(yq .management.terraform_state_container_name ${config_yaml})
export AAD_TENANT_ID=$(yq .authentication.aad_tenant_id ${config_yaml})

export API_CLIENT_ID=$(yq .authentication.api_client_id ${config_yaml})
export API_CLIENT_SECRET=$(yq .authentication.api_client_secret ${config_yaml})

export APPLICATION_ADMIN_CLIENT_ID=$(yq .authentication.application_admin_client_id ${config_yaml})
export APPLICATION_ADMIN_CLIENT_SECRET=$(yq .authentication.application_admin_client_secret ${config_yaml})

export SWAGGER_UI_CLIENT_ID=$(yq .authentication.swagger_ui_client_id ${config_yaml})

export TEST_ACCOUNT_CLIENT_ID=$(yq .authentication.test_account_client_id ${config_yaml})
export TEST_ACCOUNT_CLIENT_SECRET=$(yq .authentication.test_account_client_secret ${config_yaml})

export TEST_APP_ID="cicd-test"
export TEST_USER_NAME="cicd-test-user"
export TEST_USER_PASSWORD="cicd-test-user-pw"

export TEST_WORKSPACE_APP_ID=${API_CLIENT_ID}
export TEST_WORKSPACE_APP_SECRET=${API_CLIENT_SECRET}

for key in TRE_ID \
  ACR_NAME \
  MGMT_RESOURCE_GROUP_NAME \
  MGMT_STORAGE_ACCOUNT_NAME \
  AAD_TENANT_ID \
  API_CLIENT_ID \
  API_CLIENT_SECRET \
  APPLICATION_ADMIN_CLIENT_ID \
  APPLICATION_ADMIN_CLIENT_SECRET \
  SWAGGER_UI_CLIENT_ID \
  TEST_ACCOUNT_CLIENT_ID \
  TEST_ACCOUNT_CLIENT_SECRET \
  TEST_APP_ID \
  TEST_USER_NAME \
  TEST_USER_PASSWORD \
  TEST_WORKSPACE_APP_ID \
  TEST_WORKSPACE_APP_SECRET
do
  echo "Set secret ${key} = ${!key}"
  set_env_secret ${key} "${!key}"
done

echo "Setting Azure credentials"

sp_name="sp-aztre-cicd"
subscriptionId=$(az account show --name 'BH-LS-PMP TRE' --query id -o tsv)
#
# The clientId here is for the service principal, created with:
# az ad sp create-for-rbac --name "${sp_name}" --role Owner --scopes /subscriptions/${subscriptionId} --sdk-auth
#
clientId=$(az ad sp list --display-name 'sp-aztre-cicd' --query "[].appId" -o tsv)
clientSecret=$(az ad app credential reset \
  --id ${clientId} \
  --query "password" \
  --display-name rbac \
  --only-show-errors \
  -o tsv)
credentials="azure-credentials.json"
cat << EOF > $credentials
{
  "clientId": "${clientId}",
  "clientSecret": "${clientSecret}",
  "subscriptionId": "${subscriptionId}",
  "tenantId": "${AAD_TENANT_ID}"
}
EOF

echo set_env_secret AZURE_CREDENTIALS "$(cat ${credentials})"
set_env_secret AZURE_CREDENTIALS "$(cat ${credentials})"

echo "Setting environment variables"
gh variable set --env ${ENV} --repo ${REPO} LOCATION --body uksouth
gh variable set --env ${ENV} --repo ${REPO} LETSENCRYPT_DROP_ALL_RULES --body 1

gh secret list --repo ${REPO} --env ${ENV}
gh variable list --env ${ENV} --repo ${REPO}

echo "All done!"
