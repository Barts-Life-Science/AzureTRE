#!/bin/bash
set -o pipefail
set -o nounset
# set -o xtrace

if [ -z "$1" ]
  then
    echo 'Nexus password needs to be passed as argument'
fi

NEXUS_HOST=${2:-localhost}

timeout=300
echo 'Checking for ./nexus_repos_config directory...'
while [ ! -d "$(dirname "${BASH_SOURCE[0]}")"/nexus_repos_config ]; do
  # Wait for ./nexus_repos_config with json config files to be copied into vm
  if [ $timeout == 0 ]; then
    echo 'ERROR - Timeout while waiting for nexus_repos_config directory'
    exit 1
  fi
  sleep 1
  ((timeout--))
done

# Create proxy for each .json file
for filename in "$(dirname "${BASH_SOURCE[0]}")"/nexus_repos_config/*.json; do
    echo "Found config file: $filename. Sending to Nexus..."
    # Check if apt proxy
    base_type=$( jq .baseType "$filename" | sed 's/"//g')
    repo_type=$( jq .repoType "$filename" | sed 's/"//g')
    repo_name=$(jq .name "$filename" | sed 's/"//g')
    base_url=http://${NEXUS_HOST}/service/rest/v1/repositories/$base_type/$repo_type

    config_timeout=300
    status_code=1
    while [ "$status_code" != 201 ]; do
      status_code=$(curl -iu admin:"$1" -XPOST \
        "$base_url" \
        -H 'accept: application/json' \
        -H 'Content-Type: application/json' \
        -d @"$filename" \
        -k -s -w "%{http_code}" -o /dev/null)
      echo "Response received from Nexus: $status_code"

      if [ "$status_code" == 201 ]; then
        break
      fi

      # If Nexus rejected the request, check whether the repo already exists
      # before burning the full 300 s timeout. Nexus returns 400 for existing repos.
      exists=$(curl -su admin:"$1" \
        "http://${NEXUS_HOST}/service/rest/v1/repositories" \
        | jq -r '.[].name' | grep -c "^${repo_name}$" || true)
      if [ "$exists" -gt 0 ]; then
        echo "$repo_name already exists, skipping"
        break
      fi

      if [ $config_timeout == 0 ]; then
        echo "ERROR - Timeout while trying to configure $repo_name"
        exit 1
      fi
      sleep 1
      ((config_timeout--))
    done
done

# Configure realms required for repo authentication
echo 'Configuring realms...'
status_code=$(curl -iu admin:"$1" -XPUT \
  "http://${NEXUS_HOST}/service/rest/v1/security/realms/active" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d @"$(dirname "${BASH_SOURCE[0]}")"/nexus_realms_config.json \
  -k -s -w "%{http_code}" -o /dev/null)
echo "Response received from Nexus: $status_code"

# Add a new section to handle the VS Code extensions configuration
echo 'Configuring VS Code extensions proxy...'
status_code=$(curl -iu admin:"$1" -XPOST \
  "http://${NEXUS_HOST}/service/rest/v1/repositories/raw/proxy" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d @"$(dirname "${BASH_SOURCE[0]}")"/nexus_repos_config/vscode_extensions_proxy_conf.json \
  -k -s -w "%{http_code}" -o /dev/null)
echo "Response received from Nexus: $status_code"

# Create cleanup policy for Hugging Face - evict blobs not downloaded in 7 days.
# The default nightly "Cleanup repositories using their associated policies" system
# task will apply this; no additional task creation needed.
echo 'Creating Hugging Face cleanup policy...'
status_code=$(curl -iu admin:"$1" -XPOST \
  "http://${NEXUS_HOST}/service/rest/v1/cleanup-policies" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{"name":"huggingface-cleanup","format":"huggingface","notes":"Evict HF blobs not downloaded in 7 days","criteria":{"lastDownloaded":"7"}}' \
  -k -s -w "%{http_code}" -o /dev/null)
echo "Response received from Nexus: $status_code"
