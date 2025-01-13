# EOEPCA+ Identity and Access Management Building Block

This repository contains deployment-related files and documentation
for the EOEPCA+ IAM BB.

## Deployment-related files

The `deployment` directory contains deployment-related files.

The following subdirectories contain files that are still being
maintained and can be considered up to date:

* `examples`: Example files related to the
  [Ingress Configuration Guide](https://eoepca.readthedocs.io/projects/iam/en/latest/admin/configuration/apisix/ingress-configuration/)
* `infrastructure`: Files related to infrastructure that is needed
  for the IAM BB, but is not part of the IAM BB itself
* `helm/charts`: Files of the IAM BB Helm chart. Note that these files
  are provided for information only.
  The authoritative source of the Helm chart is the
  [helm-charts-dev repository](https://github.com/EOEPCA/helm-charts-dev/tree/develop/charts/iam-bb).

The following subdirectories contain files that were used before the
IAM BB Helm chart was introduced. They are only provided for reference,
may not be up to date and are likely to be removed in the final 2.0.0
release.

* `helm/configuration`: Example `values.yaml` files for deploying the
  components of the IAM BB without using the IAM BB Helm chart.
* `crds`: Old example APISIX CRDs 
* `scripts`: Installation and deinstallation scripts for use without the
  IAM BB Helm chart.

## Documentation

The `docs` directory contains the raw documentation files of the IAM BB. 
The documentation is automatically published on Read-the-Docs and can be
reviewed [here](https://eoepca.readthedocs.io/projects/iam/en/latest/).

## Related resources

#### Helm Chart

IAM BB Helm chart: https://github.com/EOEPCA/helm-charts-dev/tree/develop/charts/iam-bb

Chart repo: https://eoepca.github.io/helm-charts-dev

Chart name: iam-bb

#### Policy Rules

Standard policy rules repo: https://github.com/EOEPCA/iam-policies

#### Keycloak-OPA Plugin

Keycloak-OPA Adapter Plugin: https://github.com/EOEPCA/keycloak-opa-plugin

Keycloak 24.0.5 image with plugin:
```
image:
    registry: byud8gih.c1.de1.container-registry.ovh.net
    repository: eoepca/keycloak-with-opa-plugin
    tag: 0.4.0
```
