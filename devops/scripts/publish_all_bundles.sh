#!/bin/bash
set -o errexit
set -o pipefail
set -o nounset
# Uncomment this line to see each command for debugging (careful: this will show secrets!)
# set -o xtrace

publish_template() {
  local template_dir=$1
  local bundle_name
  bundle_name=$(basename "$template_dir")
  local bundle_type=$2
  local parent_bundle=$3

  if [ -f "$template_dir"/porter.yaml ]; then
    if [ "$bundle_type" == "$parent_bundle" ]; then
      echo "Publishing $bundle_type bundle $bundle_name"
      make "${bundle_type%s}"_bundle_publish BUNDLE="$bundle_name"
    else
      echo "Publishing user resource bundle $bundle_name for workspace service $parent_bundle"
      make user_resource_bundle_publish BUNDLE="$bundle_name" WORKSPACE_SERVICE="$parent_bundle"
    fi
  fi
}

find ./templates -mindepth 1 -maxdepth 1 -type d | while read -r template_type_dir; do
  template_type=$(basename "$template_type_dir")
  echo "Publishing $template_type"
  find "$template_type_dir" -mindepth 1 -maxdepth 1 -type d | while read -r template_dir; do
    template_name=$(basename "$template_dir")
    echo "Publishing $template_name $template_type template"
    publish_template "$template_dir" "$template_type" "$template_type"

    if [[ "$template_type" == "workspace_services" ]] && [ -d "$template_dir/user_resources" ]; then
      echo "Publishing user resources for $template_name"
      find "$template_dir/user_resources" -mindepth 1 -maxdepth 1 -type d | while read -r user_resource_template_dir; do
        publish_template "$user_resource_template_dir" "user_resource" "$template_name"
      done
    fi
  done
done

