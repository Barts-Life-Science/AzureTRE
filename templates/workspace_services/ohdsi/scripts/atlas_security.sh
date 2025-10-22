#!/bin/bash
set -o errexit
set -o pipefail
set -o nounset

# Wait for WebAPI to be ready
MAX_RETRIES=90
RETRY_DELAY=10
retry_count=0

echo "Waiting for WebAPI to be ready..."
while [ $retry_count -lt $MAX_RETRIES ]; do
  if curl -f -s --max-time 10 "${WEB_API_URL}info" > /dev/null 2>&1; then
    echo "WebAPI is ready!"
    break
  fi
  retry_count=$((retry_count + 1))
  echo "WebAPI not ready yet, attempt $retry_count/$MAX_RETRIES, waiting ${RETRY_DELAY}s..."
  sleep $RETRY_DELAY
done

if [ $retry_count -eq $MAX_RETRIES ]; then
  echo "ERROR: WebAPI did not become ready in time"
  exit 1
fi

psql -v ON_ERROR_STOP=1 -e "$OHDSI_ADMIN_CONNECTION_STRING" -f "../sql/atlas_create_security.sql"

psql -v ON_ERROR_STOP=1 -e "$OHDSI_ADMIN_CONNECTION_STRING" -f "../sql/atlas_default_roles.sql"

count=1
for i in ${ATLAS_USERS//,/ }
do
    if [ "$(("$count" % 2))" -eq "1" ]; then
        username=$i
    else
        # shellcheck disable=SC2016
        atlaspw=$(htpasswd -bnBC 4 "" "$i" | tr -d ':\n' | sed 's/$2y/$2a/')
        psql -v ON_ERROR_STOP=1 -e "$OHDSI_ADMIN_CONNECTION_STRING" -c "insert into webapi_security.security (email,password) values ('$username', E'$atlaspw');"
        # this step adds some required rows/ids in the db
        echo "curl ${WEB_API_URL}user/login/db --data-urlencode login=$username --data-urlencode password=$i --fail"
        curl "${WEB_API_URL}user/login/db" --data-urlencode "login=$username" --data-urlencode "password=$i" --fail

        if [ "$count" = "2" ]; then
            psql -v ON_ERROR_STOP=1 -e "$OHDSI_ADMIN_CONNECTION_STRING" -c "insert into webapi.sec_user_role (user_id, role_id) values ((select id from webapi.sec_user where login='$username'),2);" #admin role
        else
            psql -v ON_ERROR_STOP=1 -e "$OHDSI_ADMIN_CONNECTION_STRING" -c "insert into webapi.sec_user_role (user_id, role_id) values ((select id from webapi.sec_user where login='$username'),10);" #atlas user role
        fi
    fi
    ((count++))
done
