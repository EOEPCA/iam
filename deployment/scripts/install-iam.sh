#!/bin/sh

VALUES_YAML_DIR=${VALUES_YAML_DIR:-.}
IAM_VALUES_YAML=${IAM_VALUES_YAML:-${VALUES_YAML_DIR}/iam-values.yaml}

helm install --create-namespace -n iam iam eoepca/iam-bb -f $IAM_VALUES_YAML
