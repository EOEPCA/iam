# Installation

This chapter describes the deployment and initial configuration
of the Identity and Access Management (IAM) building block.

## Introduction

This section provides an introduction into the components and
deployment of the IAM BB.

### Components

The IAM BB consists of three (optionally four) components that can be deployed and
configured independently.

The core component of the IAM BB is a Keycloak server that is
installed through a [Bitnami Helm chart](https://bitnami.com/stack/keycloak/helm).
It uses a customized container image that adds the
[Keycloak-OPA plugin](https://github.com/EOEPCA/keycloak-opa-plugin)
that allows Keycloak to use policy rules that are provided by an instance
of Open Policy Agent (OPA).

The second component of the IAM BB is the Open Policy Administration
Layer (OPAL), which includes an embedded instance of OPA. It is installed
through the [OPAL Helm chart](https://github.com/permitio/opal-helm-chart).
It requires access to an external Git repository that stores policy
rules and static data associated with them. The setup includes a simple
standard security policy for OPA that prevents non-authorized clients
from reading or modifying policy code.

As a third component, the IAM BB offers a prepared instance of APISIX
that is used as the ingress controller and Policy Enforcement Point (PEP)
for the IAM BB itself and can also be used as a PEP for other BBs that
reside on the same or another cluster. It is installed through the native
Apache [Helm chart](https://github.com/apache/apisix-helm-chart/).

As an optional fourth component, the Identity API was added to the
IAM BB a while ago. However, the Identity API is meanwhile considered
deprecated and shall be removed in a later release. It is disabled by
default and should not be used productively. If enabled, the Identity
API is installed using the
[Identity Service Helm chart](https://github.com/EOEPCA/helm-charts-dev/tree/develop/charts/identity-service).

Furthermore there is a separate `iam-bb-config` Helm chart that
contains some configuration based on the Crossplane Keycloak Provider.
For instance, it helps to automate creating a `ProviderConfig`, an OPA
client and optionally a realm.

### Overall Deployment

In the [reference environment](https://github.com/EOEPCA/eoepca-plus),
the components are currently installed separately via the IAM BB Helm
chart and glued together via an ArgoCD App of Apps. This allows
maintaining the components separately in ArgoCD, but leads to a
quite complex setup.

In a typical (non-ArgoCD) environment, it is recommended to
deploy the IAM at once, except for APISIX, which should be deployed
upfront as an infrastructure component.

The IAM BB Helm chart also performs some basic configuration on the IAM.
However, the
[IAM reference deployment](https://github.com/EOEPCA/eoepca-plus/tree/deploy-develop/argocd/eoepca/iam)
still contains some objects (like certificates and sealed secrets) that
constitute a project-dependent overall setup and are therefore not handled
by the Helm chart. These objects should be reviewed and either adopted or
replaced with project-specific setup.  

## Deployment via Helm

This section describes how to install the components of the IAM BB
using Helm. 

### Preparation

The standard way of installing the IAM is by using the
[`iam-bb` Helm chart](https://github.com/EOEPCA/helm-charts-dev/tree/develop/charts/iam-bb).
Before deploying, the `values.yaml` file of the Helm chart has to be
customized. Common settings can be made in the `iam` section.
They are propagated to the individual sections through yaml anchors.
The individual sections must be kept in order for this to work properly.

Some settings can only be modified within the individual sections that
correspond to the subcharts used by the `iam-bb` Helm chart. These
sections are present in the standard `values.yaml` file, but limited
to the settings that are most commonly changed. So in rare cases it
may be necessary to take over and adapt settings from the original
`values.yaml` files of the subcharts.

For reference, pre-configured `values.yaml` files for the subcharts
can be found [here](https://github.com/EOEPCA/iam/tree/main/deployment/helm/configuration).
However, please note that these example files are not guaranteed to
be up to date. The following `values.yaml` files are supplied:
```
keycloak-values.yaml # values for Keycloak
opal-values.yaml # values for OPAL and OPA
values-identity-service.yaml # values for Identity API
apisix-values-asf.yaml # values for APISIX (using Apache Helm chart - recommended)
apisix-values-bitnami.yaml # values for APISIX (for Bitnami Helm chart - deprecated)
```
These example `values.yaml` files are preconfigured for the EOEPCA+ reference
environment. They (or the corresponding entries in the `values.yaml` file
of the `iam-bb` Helm chart) may have to be adapted to the target environment
before installing. This especially applies to the following entries:

* The reference cluster uses a non-standard storage class, which may have to
  be adjusted. This applies to Keycloak and APISIX.
  ```
  # Keycloak
  global:
    storageClass: "managed-nfs-storage-retain"
  
  # APISIX
  etcd:
    persistence:
      storageClass: managed-nfs-storage-retain
  ```

* The preset Keycloak admin password (and maybe also the username)
  should be changed, especially if Keycloak will be publicly
  accessible. In this case, it should preferably be set via a secret.
  In a protected environment, though, it may also be an option to
  deploy Keycloak with the preset password and change it manually
  after deploying.
  ```
  auth:
    adminUser: user
    adminPassword: "..."
    existingSecret: ""
    passwordSecretKey: ""
  ```

* For Keycloak, the following environment variables may have to be
  adapted. `KC_SPI_POLICY_OPA_OPA_BASE_URI` may have to be changed
  if the name of the OPAL client service deviates from the default.
  Note that the service name depends on the release name and defaults
  to the release name with `-opal-client` appended.
  `KC_HOSTNAME_URL` should be changed to the official external URL
  of the Keycloak service. The `values.yaml` file of the `iam-bb`
  Helm chart sets it implicitly via an anchor.
  ```
  extraEnvVars:
  - name: KC_SPI_POLICY_OPA_OPA_BASE_URI
    value: "http://iam-opal-opal-client:8181/v1/data/"
  - name: KC_HOSTNAME
    value: "https://iam-auth.develop.eoepca.org"
  ```

* By default, the PostgreSQL passwords are read from a secret named
  `kc-postgres`. This secret should either be created before installing
  Keycloak, or the passwords should be configured explicitly.
  ```
  postgresql:
    enabled: true
    auth:
      #postgresPassword: "..."
      username: bn_keycloak
      #password: "..."
      existingSecret: "kc-postgres"
  
  ```
  If the password is left blank, the Helm chart will generate one.
  However, this may lead to an inconsistency if Keycloak is removed
  and reinstalled later without deleting the underlying PVC.
  Therefore it is recommended to set the password to a fixed value.

* OPAL is preconfigured to use the `iam-policies` repository that contains
  a reasonable set of standard rules. This works as an initial setup
  for testing and evaluating EOEPCA, but may have to be changed to a
  project-specific repository in order to allow adding custom rules.
  ```
  server:
    policyRepoUrl: https://github.com/EOEPCA/iam-policies.git
    policyRepoSshKey: null
    policyRepoMainBranch: main
  ```

* OPAL: For a production setup, it is recommended to review and adapt
  the example access policy for OPA as it is not meant for productive use,
  though it should at least be safe enough for use in a protected
  environment.
  ```
  client:
    opaStartupData:
      policy.rego: |
        # Simple example policy gives everyone read access to non-system documents
        # and only gives a root user full access.
        [...]
  ```

* APISIX: The reference configuration defines an ingress that allows accessing
  APISIX through an existing NGinX ingress controller. This may have to be
  disabled if not required.
  ```
  ingress:
    enabled: true
  ```
  This is not necessary if APISIX is deployed using the `iam-bb` Helm chart.

* Currently APISIX is deployed in the "iam" namespace by default. If it is
  deployed in another namespace, the following setting may have to be adapted:
  ```
  ingress-controller:
    config:
      apisix:
        serviceNamespace: iam
  ```
  This is not necessary if APISIX is deployed using the `iam-bb` Helm chart.

* APISIX: In the reference environment, a NodePort service is configured
  as the standard ingress entry point. The `iam-bb` Helm chart does not
  have a default configuration for the entry point. This may have to be
  adapted.
  ```
  service:
    type: NodePort
    http:
      enabled: true
      servicePort: 80
      nodePort: 32080
    tls:
      servicePort: 443
      nodePort: 32443
  ```

### IAM-BB Helm Chart

The standard way of installing the IAM BB is through the `iam-bb`
[Helm chart](https://github.com/EOEPCA/helm-charts-dev/tree/develop/charts/iam-bb).
It allows installing all IAM BB components at once or an arbitrary subset
of them, just as required. It can also create some basic configuration like
routes automatically if desired.

The IAM BB Helm chart includes the IAM core components (Keycloak and OPAL)
as well as the optional Identity API and the APISIX ingress controller.

It is recommended to install the IAM BB in two steps. The APISIX ingress
controller is an important infrastructure component and should therefore
be installed before the IAM BB core components and any other components
that depend on it. The remaining IAM components (Keycloak, OPAL and optionally
Identity API) should be installed together in a second step. As a convention,
it is recommended to use the namespace `ingress-apisix` for APISIX and the
namespace `iam` for the IAM itself.

If a dedicated cluster is available for the IAM, it may also be installed
in a single step. APISIX may then also reside in the `iam` namespace.

The `iam-bb` Helm chart can also be used to install APISIX on other clusters
where it shall be used as an ingress controller and PEP in conjunction with
the IAM. In this case, it should use the `ingress-apisix` namespace.

#### `iam-bb-config` subchart

The `iam-bb-config` Helm chart allows automating some configuration steps
if the Crossplane Keycloak Provider is available. It is normally applied
as a subchart by the `iam-bb` chart, but it can also be used stand-alone,
e.g. if the IAM BB is deployed on another cluster than the one on which
Crossplane is available.

Basic realm initialization is normally performed by the `iam-bb` Helm
chart itself (if `iam.keycloak.configuration.useKeycloakConfigCli` is set
to `true`). The `iam-bb` chart additionally creates a client for Crossplane
if `iam.keycloak.configuration.provider.createServiceAccount` is `true`.

Building upon this basic initialization, the `iam-bb-config` Helm chart
performs the following setup:

* Create a `ProviderConfig` for the Crossplane Keycloak Provider. This
  provider can also be used by other BBs to perform Keycloak setup.
* Create and setup a `Client` for OPA and optionally Identity API

Optionally, the `iam-bb-config` chart is also able to create the realm as
a Crossplane CR. However, this only makes sense in very rare cases and
should generally be avoided.

#### Prerequisites

Depending on the chosen options the IAM-BB Helm chart requires the following
infrastructure services to be present on the cluster:

* The `iam-bb-config` Helm chart requires [Crossplane](https://www.crossplane.io/)
  and the [Crossplane Keycloak Provider](https://github.com/crossplane-contrib/provider-keycloak).
  This is also the case if the `iam-bb-config` chart is applied implicitly
  as a subchart by setting `iam.config.enabled` to `true`. If these
  prerequisites are not met, deployment of `iam-bb-config` fails.
* The `iam-bb` Helm chart generates secrets for `kubernetes-secret-generator`
  if `iam.keycloak.configuration.useSecretGenerator` is set to `true`.
  In order for these secrets to work properly, it requires
  [Kubernetes Secret Generator](https://github.com/mittwald/kubernetes-secret-generator)
  to be installed. Note that the `iam-bb` Helm chart does not rely on
  `kubernetes-secret-generator` CRDs, but generates annotations. This means
  that `iam-bb` deployment also works without `kubernetes-secret-generator`,
  but actual secret generation would not happen, which would cause follow-up
  errors.

### Alternative: Individual Helm Charts

Alternatively the IAM BB can be installed using the Helm charts of the
components of the IAM BB. Additional setup steps like creation of routes
and global configuration that are normally done by the `iam-bb` Helm chart
must be performed manually in this case.

This way of installing the IAM BB is not recommended. It is described here
primarily to provide some additional insights into the installation process. 

#### Keycloak Helm Chart

The Keycloak component can be installed as follows:

```
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm install -f keycloak-values.yaml -n iam iam-keycloak bitnami/keycloak --version 21.4.4
```

#### OPAL

The OPAL component can be installed as follows:

```
helm repo add permitio https://permitio.github.io/opal-helm-chart
helm repo update
helm install -f opal-values.yaml -n iam iam-opal permitio/opal --version 0.0.28
```

#### Identity API

The Identity API component can be installed as follows:

```
helm repo add eoepca https://eoepca.github.io/helm-charts
helm repo update
helm install -f identity-service-values.yaml -n iam identity-service eoepca/identity-service
```

#### APISIX

The APISIX component can be installed as follows:

```
helm repo add apisix https://charts.apiseven.com
helm repo update
helm install -f apisix-values-asf.yaml -n iam apisix apisix/apisix --version 2.9.0
```

Note that APISIX can also be installed as an ingress controller
and PEP on another cluster. In this case, a different namespace (default:
`ingress-apisix`) should be used.

#### Prepared Scripts

The [IAM repository](https://github.com/EOEPCA/iam) contains
simple prepared installation and deinstallation
[scripts](https://github.com/EOEPCA/iam/tree/main/deployment/scripts)
that encapsulate the Helm commands. The location of the
`values.yaml` files can be configured through environment variables.
For other adaptations (like non-standard namespaces), the scripts
must be adapted manually.

The scripts are mostly useful for test environments where IAM
components need to be updated or deployed from scratch quite
frequently.

## Further Setup

In order to make the IAM BB accessible from outside the cluster,
appropriate routes (aka ingresses) and TLS certificates need to
be configured.

This can be done by creating standard `Ingress` objects or
APISIX-specific `ApisixTls` and `ApisixRoute` objects. The latter allow
using APISIX-specific features and plugins that cannot be
configured using standard Ingress objects. Furthermore, they
allow separating the TLS configuration from the actual route
definitions.

Note that the `iam-bb` Helm chart can create the EOEPCA realm as well as
the routes and clients for Keycloak, OPA and Identity API automatically
as far as desired. Alternatively they can be configured manually.

Note, however, that the TLS configuration must always be provided
manually, because it heavily depends on the environment.

Finally, some further manual configuration may need to be done in
Keycloak:

* Configure GitHub as IdP
* Configure further IdPs
* Configure e-mail handling

### TLS Configuration

The TLS configuration depends on the issuers that are available in
your cluster. It requires a `Certificate` object and an `ApisixTls`
object per certificate. In the reference environment, a global wildcard
certificate is used. This makes all routes within the scope of the
certificate support TLS without any further configuration.
Note that the separate `Certificate` object is needed, because Cert
Manager does not honour `cert-manager.io/cluster-issuer` annotations
on an `ApisixTls` object.

Example from the reference environment:

```
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: apx-all
  namespace: iam
spec:
  secretName: apx-all-tls
  duration: 2160h # 90d
  renewBefore: 360h # 15d
  isCA: false
  usages:
    - server auth
    - client auth
  dnsNames:
    - "*.apx.develop.eoepca.org"
  issuerRef:
    name: letsencrypt-dns-prod
    kind: ClusterIssuer
---
apiVersion: apisix.apache.org/v2
kind: ApisixTls
metadata:
  name: apx-all-tls
  namespace: iam
spec:
  hosts:
    - "*.apx.develop.eoepca.org"
  secret:
    name: apx-all-tls
    namespace: iam
```

### Route Configuration

A route needs to be configured at least for Keycloak.
Optionally, further routes can be added for Open Policy Agent (OPA)
and any other services that need to be accessible from outside the
cluster. The `iam-bb` Helm chart does this automatically based on
the settings made in the `values.yaml` file.

The following is an example route definition for Keycloak:

```
apiVersion: apisix.apache.org/v2
kind: ApisixRoute
metadata:
  name: keycloak-route
  namespace: iam
  annotations:
    ingress.kubernetes.io/ssl-redirect: "true"
    cert-manager.io/cluster-issuer: letsencrypt-prod
    argocd.argoproj.io/sync-wave: "2"
spec:
  http:
  - backends:
    - serviceName: iam-keycloak
      servicePort: 80
    match:
      hosts:
      - iam-auth.apx.develop.eoepca.org
      paths:
      - /*
    name: keycloak
```

The following route is an example route for OPA. It includes
authentication and authorization via Keycloak and serves as an
example for a protected ingress. In case of OPA, the `authz-keycloak`
plugin is optional, because OPA handles authorization itself based
on a configured policy and the JWT passed by Keycloak. However, the
plugin would allow configuring further restrictions on OPA in
Keycloak.

```
apiVersion: apisix.apache.org/v2
kind: ApisixRoute
metadata:
  name: opa-route
spec:
  http:
  - name: opa-apx
    match:
      hosts:
        - iam-opa.apx.develop.eoepca.org
      paths:
        - /*
    backends:
      - serviceName: iam-opal-opal-client
        servicePort: 8181
    plugins:
      - name: openid-connect
        enable: true
        config:
          client_id: "opa"
          client_secret: "..."
          access_token_in_authorization_header: true
          use_jwks: true
          discovery: "https://iam-auth.apx.develop.eoepca.org/realms/eoepca/.well-known/openid-configuration"
        # Alternative to hide sensitive information like the client secret:
        # secretRef: my-secret
      - name: authz-keycloak
        enable: true
        config:
          client_id: "opa"
          client_secret: "..."
          discovery: "https://iam-auth.apx.develop.eoepca.org/realms/eoepca/.well-known/uma2-configuration"
          lazy_load_paths: true
        # secretRef: my-secret
```

Note that any portions of the plugin configurations can be stored in a secret.
This allows hiding sensitive information like the client secret from the
route definition. More information can be found in the
[APISIX Documentation](https://apisix.apache.org/docs/ingress-controller/concepts/apisix_route/#config-with-secretref)
and the [Ingress Configuration Guide](https://eoepca.readthedocs.io/projects/iam/en/latest/admin/configuration/apisix/ingress-configuration/).

## Keycloak Configuration

Finally, some manual configuration may need to be done in Keycloak
unless they have already been performed by the IAM-BB Helm chart.
The potential steps are described in the following subsections.

### Create realm

A manual procedure for creating and configuring the `eoepca` realm
is described in [this guide](https://eoepca.readthedocs.io/projects/iam/en/latest/admin/configuration/keycloak/keycloak-configuration/).

A `curl`-based alternative is described in the
[IAM Deployment Guide](https://eoepca.readthedocs.io/projects/deploy/en/2.0-beta/building-blocks/iam/#5-create-eoepca-keycloak-realm).

### Create OPA client

Using the Keycloak Admin UI, create a client with the following settings:
* Client ID: "opa"
* Root URL: External OPA base URL as configured in `values.yaml`
* Valid redirect URIs: "/*"
* Web origins: "/*"
* Home URL and Admin URL may be set to the same value as Root URL
* Client authentication: On
* Authentication flow: Standard flow + Service account roles
* All other settings may be left at their default values or set as desired.

Take over the generated client secret from the Keycloak UI to the
OPA route secret.

A `curl`-based alternative is described in the
[IAM Deployment Guide](https://eoepca.readthedocs.io/projects/deploy/en/2.0-beta/building-blocks/iam/#a-create-keycloak-client-for-opa).

The advantage of the latter solution is that the client secret can be set
to a pregenerated value when creating the client. This saves the
effort of updating the OPA route secret manually.

### Identity API client

Using the Keycloak Admin UI, create a client with the following settings:
* Client ID: "identity-api"
* Root URL: External Identity API base URL as configured in `values.yaml`
* Valid redirect URIs: "/*"
* Web origins: "/*"
* Home URL and Admin URL may be set to the same value as Root URL
* Client authentication: On
* Authorization: On
* Authentication flow: Standard flow + Service account roles
* Create a policy that restricts access. Only trusted users should
  have access to the Identity API
* Update the default permission to refer to this policy
* All other settings may be left at their default values or set as desired.

Take over the generated client secret from the Keycloak UI to the
Identity API route secret.

Alternatively the client can be created using the `curl`-based approach
as described for the OPA client.

### Configure GitHub as IdP

A manual procedure for configuring GitHub as an external Identity
Provider for the IAM is described
[here](https://eoepca.readthedocs.io/projects/iam/en/latest/admin/configuration/github-idp/github-setup-idp/).
The guide may also be used for integrating with other external IdPs.

A `curl`-based alternative is described in the
[IAM Deployment Guide](https://eoepca.readthedocs.io/projects/deploy/en/2.0-beta/building-blocks/iam/#7-integrate-github-as-external-identity-provider)
