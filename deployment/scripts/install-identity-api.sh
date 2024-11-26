#!/bin/sh

VALUES_YAML_DIR=${VALUES_YAML_DIR:-.}
API_VALUES_YAML=${API_VALUES_YAML:-${VALUES_YAML_DIR}/identity-service-values.yaml}

helm install --create-namespace -n iam identity-service eoepca/identity-service -f $API_VALUES_YAML
