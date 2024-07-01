#!/bin/sh

helm install keycloak oci://registry-1.docker.io/bitnamicharts/keycloak -n eoepca -f values.yaml
