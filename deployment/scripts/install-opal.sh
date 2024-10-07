#!/bin/sh

VALUES_YAML_DIR=${VALUES_YAML_DIR:-.}
OPAL_VALUES_YAML=${OPAL_VALUES_YAML:-${VALUES_YAML_DIR}/opal-values.yaml}

helm install -f $OPAL_VALUES_YAML -n iam iam-opal permitio/opal --version 0.0.28
