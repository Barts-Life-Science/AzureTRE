#!/bin/bash
set -o errexit
set -o pipefail
set -o nounset

echo "...0" >&2
if [[ -z ${DATA_SOURCE_CONFIG:-} ]] || [[ -z ${DATA_SOURCE_DIAMONS:-} ]]; then
  printf 'No data source or daimons configured.'
  exit 0
else
  # Parse Data source
echo "...1" >&2
  ds_config="$(echo "$DATA_SOURCE_CONFIG" | base64 --decode)"
  ds_daimons="$(echo "$DATA_SOURCE_DIAMONS" | base64 --decode)"
  dialect="$(jq -r '.dialect' <<< "$ds_config")"

  if [[ $dialect != "Azure Synapse" ]]; then
    printf 'Not a Synapse data source, no action required.'
    exit 0
  fi

  origin_results_schema_name="$(jq -r '.daimon_results' <<< "$ds_daimons")"
  origin_temp_schema_name="$(jq -r '.daimon_temp' <<< "$ds_daimons")"
  if [[ -z $origin_results_schema_name ]] || [[ -z $origin_temp_schema_name ]]; then
    printf 'Results and temp schemas are not configured.'
    exit 0
  fi

echo "...2" >&2
  # Parse required info
  admin_user="$(jq -r '.username' <<< "$ds_config")"
echo "...3" >&2
  jdbc_connection_string="$(jq -r '.connection_string' <<< "$ds_config")"
echo "...4" >&2
  synapse_server="$([[ $jdbc_connection_string =~ jdbc:sqlserver://(.*):1433 ]] &&  echo "${BASH_REMATCH[1]}")"
echo "...5" >&2
  synapse_db="$([[ $jdbc_connection_string =~ database=(.*)(;user) ]] &&  echo "${BASH_REMATCH[1]}")"
echo "...6" >&2
  origin_results_schema_name="$(jq -r '.daimon_results' <<< "$ds_daimons")"
echo "...7" >&2
  origin_temp_schema_name="$(jq -r '.daimon_temp' <<< "$ds_daimons")"
echo "...8" >&2
  parsed_resource_id="$(echo "$TRE_RESOURCE_ID" | tr - _ )"
echo "...9" >&2
  results_schema_name="${origin_results_schema_name}_${parsed_resource_id}"
echo "...10" >&2
  temp_schema_name="${origin_temp_schema_name}_${parsed_resource_id}"
echo "...11" >&2

  # Export password as required by sqlcmd tool
  # shellcheck disable=SC2155
echo "...12" >&2
  export SQLCMDPASSWORD="$(jq -r '.password' <<< "$ds_config")"
echo "...13" >&2

  printf 'Execute Synapse SQL script'
echo "...14" >&2
  sqlcmd -U "${admin_user}" -S "${synapse_server}" -d "${synapse_db}" -W -v RESULTS_SCHEMA_NAME="${results_schema_name}" -v TEMP_SCHEMA_NAME="${temp_schema_name}" -v ORIGIN_RESULTS_SCHEMA_NAME="${origin_results_schema_name}" -i "${SCRIPT_PATH}"
echo "...15" >&2
  printf 'Execute Synapse SQL script: done.'
echo "...16" >&2
  exit 0
fi
echo "...17" >&2
