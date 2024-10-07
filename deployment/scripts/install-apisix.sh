#!/bin/sh

VALUES_YAML_DIR=${VALUES_YAML_DIR:-.}
APISIX_VALUES_YAML=${APISIX_VALUES_YAML:-${VALUES_YAML_DIR}/apisix-values-asf.yaml}

helm install --create-namespace -n iam apisix apisix/apisix --version 2.9.0 -f $APISIX_VALUES_YAML

# Bitnami (older chart version):
#helm install apisix oci://registry-1.docker.io/bitnamicharts/apisix --version 2.5.8 -n iam -f $APISIX_VALUES_YAML
