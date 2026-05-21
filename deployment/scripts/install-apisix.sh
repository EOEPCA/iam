#!/bin/sh

VALUES_YAML_DIR=${VALUES_YAML_DIR:-.}
APISIX_VALUES_YAML=${APISIX_VALUES_YAML:-${VALUES_YAML_DIR}/apisix-values-asf.yaml}

helm install --create-namespace -n iam apisix apisix/apisix --version 2.13.0 -f $APISIX_VALUES_YAML
