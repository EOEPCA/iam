#!/bin/sh

#if [ `helm -n eoepca list -q -f keycloak|wc -l` -gt 0 ]; then
helm -n iam uninstall apisix
#kubectl -n eoepca delete pvc data-keycloak-postgresql-0
#fi
