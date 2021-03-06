#!/bin/bash

set -eu

CF_GUID=$(
  om-linux \
    --target https://$OPS_MGR_HOST \
    --username "$OPS_MGR_USR" \
    --password "$OPS_MGR_PWD" \
    --skip-ssl-validation \
    curl --silent --path "/api/v0/deployed/products" | \
    jq -r '.[] | .installation_name' | grep cf- | tail -1
)
export CF_GUID=$CF_GUID
echo $CF_GUID

SYS_DOMAIN=$(
  om-linux \
  --target https://$OPS_MGR_HOST \
  --username "$OPS_MGR_USR" \
  --password "$OPS_MGR_PWD" \
    --skip-ssl-validation \
    curl --silent --path "/api/v0/staged/products/${CF_GUID}/properties" | \
    jq --raw-output '.[] | .[".cloud_controller.system_domain"].value'
)
echo api.$SYS_DOMAIN

ADMIN_PW=$(
  om-linux \
  --target https://$OPS_MGR_HOST \
  --username "$OPS_MGR_USR" \
  --password "$OPS_MGR_PWD" \
    --skip-ssl-validation \
    curl --silent --path "/api/v0/deployed/products/${CF_GUID}/credentials/.uaa.admin_credentials" | \
    jq -r '.[] | .value.password'
)

ADMIN_CLIENT_PW=$(
  om-linux \
  --target https://$OPS_MGR_HOST \
  --username "$OPS_MGR_USR" \
  --password "$OPS_MGR_PWD" \
    --skip-ssl-validation \
    curl --silent --path "/api/v0/deployed/products/${CF_GUID}/credentials/.uaa.admin_client_credentials" | \
    jq -r '.[] | .value.password'
)

cf login -a https://api.$SYS_DOMAIN -u admin -p $ADMIN_PW --skip-ssl-validation -o system -s system

cf create-user $PAS_ADMIN_USERNAME $PAS_ADMIN_PASSWORD
cf set-org-role $PAS_ADMIN_USERNAME system OrgManager
cf set-org-role $PAS_ADMIN_USERNAME system BillingManager
cf set-org-role $PAS_ADMIN_USERNAME system OrgAuditor

cf logout

uaac target uaa.$SYS_DOMAIN --skip-ssl-validation
uaac token client get admin -s $ADMIN_CLIENT_PW

set +eu
uaac contexts
CHK=$(
  uaac users| grep $PAS_ADMIN_USERNAME
)
if [ -z "$CHK" ]; then
  uaac user add $PAS_ADMIN_USERNAME -p $PAS_ADMIN_PASSWORD --emails $EMAIL
fi
uaac member add cloud_controller.admin $PAS_ADMIN_USERNAME
uaac member add uaa.admin $PAS_ADMIN_USERNAME
uaac member add scim.read $PAS_ADMIN_USERNAME
uaac member add scim.write $PAS_ADMIN_USERNAME

uaac token delete
set -eu
