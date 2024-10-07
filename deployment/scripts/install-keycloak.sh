#!/bin/sh

VALUES_YAML_DIR=${VALUES_YAML_DIR:-.}
KEYCLOAK_VALUES_YAML=${KEYCLOAK_VALUES_YAML:-${VALUES_YAML_DIR}/keycloak-values.yaml}

helm install iam-keycloak oci://registry-1.docker.io/bitnamicharts/keycloak --version 21.4.4 -n iam -f $KEYCLOAK_VALUES_YAML
