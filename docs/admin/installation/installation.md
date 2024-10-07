# Installation

## Introduction

### Components

The IAM BB consists of three components that can be deployed and
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
that is used as the ingress controller and Police Enforcement Point (PEP)
for the IAM BB itself and can also be used as a PEP for other BBs that
reside on the same or another cluster. It is installed through the native
Apache [Helm chart](https://github.com/apache/apisix-helm-chart/).

### Overall Deployment

The components are currently glued together via an ArgoCD App of Apps.
The main app still contains some objects (like certificates
and ingress routes) that should actually be part of the individual
components or an overall setup. This will be cleaned up as the IAM BB
evolves. It is also planned to provide a Helm chart that wraps
Keycloak and OPAL. APISIX, however, will probably remain separate,
because it is rather an infrastructure service than an integrated part
of the IAM BB.

The ArgoCD-based configuration for the test environment can be found
[here](https://github.com/EOEPCA/eoepca-plus/tree/deploy-develop/argocd/eoepca/iam).

## Deployment via Helm

### Preparation

All IAM components presently use standard Helm charts in combination
with custom `values.yaml` files that configure them for the IAM BB.
The following `values.yaml` files are supplied:
```
keycloak-values.yaml # values for Keycloak
opal-values.yaml # values for OPAL and OPA
apisix-values-asf.yaml # values for APISIX (using Apache Helm chart)
apisix-values-bitnami.yaml # values for APISIX (for Bitnami Helm chart - unused)
```
They can be found [here](https://github.com/EOEPCA/iam/tree/main/deployment/helm/configuration).

The `values.yaml` files are preconfigured for the EOEPCA+ test
environment and may have to be adapted for the target environment
before installing. This especially applies to the following entries:

* The test cluster uses a non-standard storage class, which should
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
  `KC_HOSTNAME_URL` and `KC_HOSTNAME_ADMIN_URL` should be changed
  to the official external URL of the Keycloak service.
  ```
  extraEnvVars:
  - name: KC_SPI_POLICY_OPA_OPA_BASE_URI
    value: "http://iam-opal-opal-client:8181/v1/data/"
  - name: KC_HOSTNAME_URL
    value: "https://iam-auth.develop.eoepca.org"
  - name: KC_HOSTNAME_ADMIN_URL
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

* OPAL is configured to use a default repository that contains some
  dummy rules. This should work as an initial setup for testing, but
  may have to be changed to a another repository in order to allow
  adding custom rules.
  ```
  server:
    policyRepoUrl: https://github.com/EOEPCA/keycloak-opa-plugin.git/
    policyRepoSshKey: null
    policyRepoMainBranch: opatest
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

* APISIX: The test configuration defines an ingress that allows accessing
  APISIX through an existing NGinX ingress controller. This should be
  disabled if not required.
  ```
  ingress:
    enabled: true
  ```

* Currently APISIX is deployed in the "iam" namespace by default. If it is
  deployed in another namespace, the following setting needs to be adapted:
  ```
  ingress-controller:
    config:
      apisix:
        serviceNamespace: iam
  ```

* APISIX: A NodePort service is configured as the standard ingress entry
  point. This may have to be adapted.
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

### Keycloak

**TODO: Use same Helm command syntax as for OPAL and APISIX**

The Keycloak component can be installed as follows:

```
helm install iam-keycloak oci://registry-1.docker.io/bitnamicharts/keycloak --version 21.4.4 \
  -n iam -f keycloak-values.yaml
```

### OPAL

The OPAL component can be installed as follows:

```
helm repo add permitio https://permitio.github.io/opal-helm-chart
helm repo update
helm install -f opal-values.yaml -n iam iam-opal permitio/opal --version 0.0.28
```

### APISIX

The APISIX component can be installed as follows:

```
helm repo add apisix https://charts.apiseven.com
helm repo update
helm install -f apisix-values-asf.yaml -n iam apisix apisix/apisix --version 2.9.0
```

Note that APISIX can also be installed as an ingress controller
and PEP on another cluster. In this case, a different namespace (default:
`ingress-apisix`) should be used.

### Further Setup

In order to make the IAM BB accessible from outside the cluster,
appropriate routes (aka ingresses) and TLS certificates need to
be configured.

This can be done by creating standard `Ingress` objects or
APISIX-specific `ApisixTls` and `ApisixRoute` objects. The latter allow
using APISIX-specific features and plugins that cannot be
configured using standard Ingress objects. Furthermore, they
allow separating the TLS configuration from the actual route
definitions.

#### TLS Configuiration

The TLS configuration depends on the issuers that are available in
your cluster. It requires a `Certificate` object and an `ApisixTls`
object per certificate. In the test environment, a global wildcard
certificate is used. This makes all routes within the scope of the
certificate support TLS without any further configuration.
Note that the separate `Certificate` object is needed, because Cert
Manager does not seem to honour `cert-manager.io/cluster-issuer`
annotations on an `ApisixTls` object.

Example from the test environment:

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

#### Route Configuration

A route need to be configured at least for Keycloak.
Optionally, further routes can be added for Open Policy Agent (OPA)
and any other services that need to be accessible from outside the
cluster.

The following is an example route definition for Keycloak. It includes
a workaround for a potential issue that causes redirects to address a
container port (9443) instead of the official HTTPS port (443).

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
    plugins:
      # Possible workaround for redirect-to-9443 problem that also works for HTTP
      - name: serverless-pre-function
        enable: true
        config:
          phase: "rewrite"
          functions:
            - "return function(conf, ctx) if tonumber(ngx.var.var_x_forwarded_port) > 9000 then ngx.var.var_x_forwarded_port = ngx.var.var_x_forwarded_port - 9000 end end"
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
[APISIX documentation](https://apisix.apache.org/docs/ingress-controller/concepts/apisix_route/#config-with-secretref).
# Installation

## Introduction

### Components

The IAM BB consists of three components that can be deployed and
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
that is used as the ingress controller and Police Enforcement Point (PEP)
for the IAM BB itself and can also be used as a PEP for other BBs that
reside on the same or another cluster. It is installed through the native
Apache [Helm chart](https://github.com/apache/apisix-helm-chart/).

### Overall Deployment

The components are currently glued together via an ArgoCD App of Apps.
The main app still contains some objects (like certificates
and ingress routes) that should actually be part of the individual
components or an overall setup. This will be cleaned up as the IAM BB
evolves. It is also planned to provide a Helm chart that wraps
Keycloak and OPAL. APISIX, however, will probably remain separate,
because it is rather an infrastructure service than an integrated part
of the IAM BB.

The ArgoCD-based configuration for the test environment can be found
[here](https://github.com/EOEPCA/eoepca-plus/tree/deploy-develop/argocd/eoepca/iam).

## Deployment via Helm

### Preparation

All IAM components presently use standard Helm charts in combination
with custom `values.yaml` files that configure them for the IAM BB.
The following `values.yaml` files are supplied:
```
keycloak-values.yaml # values for Keycloak
opal-values.yaml # values for OPAL and OPA
apisix-values-asf.yaml # values for APISIX (using Apache Helm chart)
apisix-values-bitnami.yaml # values for APISIX (for Bitnami Helm chart - unused)
```
They can be found [here](https://github.com/EOEPCA/iam/tree/main/deployment/helm/configuration).

The `values.yaml` files are preconfigured for the EOEPCA+ test
environment and may have to be adapted for the target environment
before installing. This especially applies to the following entries:

* The test cluster uses a non-standard storage class, which should
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
  `KC_HOSTNAME_URL` and `KC_HOSTNAME_ADMIN_URL` should be changed
  to the official external URL of the Keycloak service.
  ```
  extraEnvVars:
  - name: KC_SPI_POLICY_OPA_OPA_BASE_URI
    value: "http://iam-opal-opal-client:8181/v1/data/"
  - name: KC_HOSTNAME_URL
    value: "https://iam-auth.develop.eoepca.org"
  - name: KC_HOSTNAME_ADMIN_URL
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

* OPAL is configured to use a default repository that contains some
  dummy rules. This should work as an initial setup for testing, but
  may have to be changed to a another repository in order to allow
  adding custom rules.
  ```
  server:
    policyRepoUrl: https://github.com/EOEPCA/keycloak-opa-plugin.git/
    policyRepoSshKey: null
    policyRepoMainBranch: opatest
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

* APISIX: The test configuration defines an ingress that allows accessing
  APISIX through an existing NGinX ingress controller. This should be
  disabled if not required.
  ```
  ingress:
    enabled: true
  ```

* Currently APISIX is deployed in the "iam" namespace by default. If it is
  deployed in another namespace, the following setting needs to be adapted:
  ```
  ingress-controller:
    config:
      apisix:
        serviceNamespace: iam
  ```

* APISIX: A NodePort service is configured as the standard ingress entry
  point. This may have to be adapted.
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

### Keycloak

**TODO: Use same Helm command syntax as for OPAL and APISIX**

The Keycloak component can be installed as follows:

```
helm install iam-keycloak oci://registry-1.docker.io/bitnamicharts/keycloak --version 21.4.4 \
  -n iam -f keycloak-values.yaml
```

### OPAL

The OPAL component can be installed as follows:

```
helm repo add permitio https://permitio.github.io/opal-helm-chart
helm repo update
helm install -f opal-values.yaml -n iam iam-opal permitio/opal --version 0.0.28
```

### APISIX

The APISIX component can be installed as follows:

```
helm repo add apisix https://charts.apiseven.com
helm repo update
helm install -f apisix-values-asf.yaml -n iam apisix apisix/apisix --version 2.9.0
```

Note that APISIX can also be installed as an ingress controller
and PEP on another cluster. In this case, a different namespace (default:
`ingress-apisix`) should be used.

### Further Setup

In order to make the IAM BB accessible from outside the cluster,
appropriate routes (aka ingresses) and TLS certificates need to
be configured.

This can be done by creating standard `Ingress` objects or
APISIX-specific `ApisixTls` and `ApisixRoute` objects. The latter allow
using APISIX-specific features and plugins that cannot be
configured using standard Ingress objects. Furthermore, they
allow separating the TLS configuration from the actual route
definitions.

#### TLS Configuiration

The TLS configuration depends on the issuers that are available in
your cluster. It requires a `Certificate` object and an `ApisixTls`
object per certificate. In the test environment, a global wildcard
certificate is used. This makes all routes within the scope of the
certificate support TLS without any further configuration.
Note that the separate `Certificate` object is needed, because Cert
Manager does not seem to honour `cert-manager.io/cluster-issuer`
annotations on an `ApisixTls` object.

Example from the test environment:

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

#### Route Configuration

A route need to be configured at least for Keycloak.
Optionally, further routes can be added for Open Policy Agent (OPA)
and any other services that need to be accessible from outside the
cluster.

The following is an example route definition for Keycloak. It includes
a workaround for a potential issue that causes redirects to address a
container port (9443) instead of the official HTTPS port (443).

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
    plugins:
      # Possible workaround for redirect-to-9443 problem that also works for HTTP
      - name: serverless-pre-function
        enable: true
        config:
          phase: "rewrite"
          functions:
            - "return function(conf, ctx) if tonumber(ngx.var.var_x_forwarded_port) > 9000 then ngx.var.var_x_forwarded_port = ngx.var.var_x_forwarded_port - 9000 end end"
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
[APISIX documentation](https://apisix.apache.org/docs/ingress-controller/concepts/apisix_route/#config-with-secretref).
# Installation

## Introduction

### Components

The IAM BB consists of three components that can be deployed and
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
that is used as the ingress controller and Police Enforcement Point (PEP)
for the IAM BB itself and can also be used as a PEP for other BBs that
reside on the same or another cluster. It is installed through the native
Apache [Helm chart](https://github.com/apache/apisix-helm-chart/).

### Overall Deployment

The components are currently glued together via an ArgoCD App of Apps.
The main app still contains some objects (like certificates
and ingress routes) that should actually be part of the individual
components or an overall setup. This will be cleaned up as the IAM BB
evolves. It is also planned to provide a Helm chart that wraps
Keycloak and OPAL. APISIX, however, will probably remain separate,
because it is rather an infrastructure service than an integrated part
of the IAM BB.

The ArgoCD-based configuration for the test environment can be found
[here](https://github.com/EOEPCA/eoepca-plus/tree/deploy-develop/argocd/eoepca/iam).

## Deployment via Helm

### Preparation

All IAM components presently use standard Helm charts in combination
with custom `values.yaml` files that configure them for the IAM BB.
The following `values.yaml` files are supplied:
```
keycloak-values.yaml # values for Keycloak
opal-values.yaml # values for OPAL and OPA
apisix-values-asf.yaml # values for APISIX (using Apache Helm chart)
apisix-values-bitnami.yaml # values for APISIX (for Bitnami Helm chart - unused)
```
They can be found [here](https://github.com/EOEPCA/iam/tree/main/deployment/helm/configuration).

The `values.yaml` files are preconfigured for the EOEPCA+ test
environment and may have to be adapted for the target environment
before installing. This especially applies to the following entries:

* The test cluster uses a non-standard storage class, which should
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
  `KC_HOSTNAME_URL` and `KC_HOSTNAME_ADMIN_URL` should be changed
  to the official external URL of the Keycloak service.
  ```
  extraEnvVars:
  - name: KC_SPI_POLICY_OPA_OPA_BASE_URI
    value: "http://iam-opal-opal-client:8181/v1/data/"
  - name: KC_HOSTNAME_URL
    value: "https://iam-auth.develop.eoepca.org"
  - name: KC_HOSTNAME_ADMIN_URL
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

* OPAL is configured to use a default repository that contains some
  dummy rules. This should work as an initial setup for testing, but
  may have to be changed to a another repository in order to allow
  adding custom rules.
  ```
  server:
    policyRepoUrl: https://github.com/EOEPCA/keycloak-opa-plugin.git/
    policyRepoSshKey: null
    policyRepoMainBranch: opatest
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

* APISIX: The test configuration defines an ingress that allows accessing
  APISIX through an existing NGinX ingress controller. This should be
  disabled if not required.
  ```
  ingress:
    enabled: true
  ```

* Currently APISIX is deployed in the "iam" namespace by default. If it is
  deployed in another namespace, the following setting needs to be adapted:
  ```
  ingress-controller:
    config:
      apisix:
        serviceNamespace: iam
  ```

* APISIX: A NodePort service is configured as the standard ingress entry
  point. This may have to be adapted.
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

### Keycloak

**TODO: Use same Helm command syntax as for OPAL and APISIX**

The Keycloak component can be installed as follows:

```
helm install iam-keycloak oci://registry-1.docker.io/bitnamicharts/keycloak --version 21.4.4 \
  -n iam -f keycloak-values.yaml
```

### OPAL

The OPAL component can be installed as follows:

```
helm repo add permitio https://permitio.github.io/opal-helm-chart
helm repo update
helm install -f opal-values.yaml -n iam iam-opal permitio/opal --version 0.0.28
```

### APISIX

The APISIX component can be installed as follows:

```
helm repo add apisix https://charts.apiseven.com
helm repo update
helm install -f apisix-values-asf.yaml -n iam apisix apisix/apisix --version 2.9.0
```

Note that APISIX can also be installed as an ingress controller
and PEP on another cluster. In this case, a different namespace (default:
`ingress-apisix`) should be used.

### Further Setup

In order to make the IAM BB accessible from outside the cluster,
appropriate routes (aka ingresses) and TLS certificates need to
be configured.

This can be done by creating standard `Ingress` objects or
APISIX-specific `ApisixTls` and `ApisixRoute` objects. The latter allow
using APISIX-specific features and plugins that cannot be
configured using standard Ingress objects. Furthermore, they
allow separating the TLS configuration from the actual route
definitions.

#### TLS Configuiration

The TLS configuration depends on the issuers that are available in
your cluster. It requires a `Certificate` object and an `ApisixTls`
object per certificate. In the test environment, a global wildcard
certificate is used. This makes all routes within the scope of the
certificate support TLS without any further configuration.
Note that the separate `Certificate` object is needed, because Cert
Manager does not seem to honour `cert-manager.io/cluster-issuer`
annotations on an `ApisixTls` object.

Example from the test environment:

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

#### Route Configuration

A route need to be configured at least for Keycloak.
Optionally, further routes can be added for Open Policy Agent (OPA)
and any other services that need to be accessible from outside the
cluster.

The following is an example route definition for Keycloak. It includes
a workaround for a potential issue that causes redirects to address a
container port (9443) instead of the official HTTPS port (443).

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
    plugins:
      # Possible workaround for redirect-to-9443 problem that also works for HTTP
      - name: serverless-pre-function
        enable: true
        config:
          phase: "rewrite"
          functions:
            - "return function(conf, ctx) if tonumber(ngx.var.var_x_forwarded_port) > 9000 then ngx.var.var_x_forwarded_port = ngx.var.var_x_forwarded_port - 9000 end end"
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
[APISIX documentation](https://apisix.apache.org/docs/ingress-controller/concepts/apisix_route/#config-with-secretref).
# Installation

## Introduction

### Components

The IAM BB consists of three components that can be deployed and
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
that is used as the ingress controller and Police Enforcement Point (PEP)
for the IAM BB itself and can also be used as a PEP for other BBs that
reside on the same or another cluster. It is installed through the native
Apache [Helm chart](https://github.com/apache/apisix-helm-chart/).

### Overall Deployment

The components are currently glued together via an ArgoCD App of Apps.
The main app still contains some objects (like certificates
and ingress routes) that should actually be part of the individual
components or an overall setup. This will be cleaned up as the IAM BB
evolves. It is also planned to provide a Helm chart that wraps
Keycloak and OPAL. APISIX, however, will probably remain separate,
because it is rather an infrastructure service than an integrated part
of the IAM BB.

The ArgoCD-based configuration for the test environment can be found
[here](https://github.com/EOEPCA/eoepca-plus/tree/deploy-develop/argocd/eoepca/iam).

## Deployment via Helm

### Preparation

All IAM components presently use standard Helm charts in combination
with custom `values.yaml` files that configure them for the IAM BB.
The following `values.yaml` files are supplied:
```
keycloak-values.yaml # values for Keycloak
opal-values.yaml # values for OPAL and OPA
apisix-values-asf.yaml # values for APISIX (using Apache Helm chart)
apisix-values-bitnami.yaml # values for APISIX (for Bitnami Helm chart - unused)
```
They can be found [here](https://github.com/EOEPCA/iam/tree/main/deployment/helm/configuration).

The `values.yaml` files are preconfigured for the EOEPCA+ test
environment and may have to be adapted for the target environment
before installing. This especially applies to the following entries:

* The test cluster uses a non-standard storage class, which should
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
  `KC_HOSTNAME_URL` and `KC_HOSTNAME_ADMIN_URL` should be changed
  to the official external URL of the Keycloak service.
  ```
  extraEnvVars:
  - name: KC_SPI_POLICY_OPA_OPA_BASE_URI
    value: "http://iam-opal-opal-client:8181/v1/data/"
  - name: KC_HOSTNAME_URL
    value: "https://iam-auth.develop.eoepca.org"
  - name: KC_HOSTNAME_ADMIN_URL
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

* OPAL is configured to use a default repository that contains some
  dummy rules. This should work as an initial setup for testing, but
  may have to be changed to a another repository in order to allow
  adding custom rules.
  ```
  server:
    policyRepoUrl: https://github.com/EOEPCA/keycloak-opa-plugin.git/
    policyRepoSshKey: null
    policyRepoMainBranch: opatest
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

* APISIX: The test configuration defines an ingress that allows accessing
  APISIX through an existing NGinX ingress controller. This should be
  disabled if not required.
  ```
  ingress:
    enabled: true
  ```

* Currently APISIX is deployed in the "iam" namespace by default. If it is
  deployed in another namespace, the following setting needs to be adapted:
  ```
  ingress-controller:
    config:
      apisix:
        serviceNamespace: iam
  ```

* APISIX: A NodePort service is configured as the standard ingress entry
  point. This may have to be adapted.
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

### Keycloak

**TODO: Use same Helm command syntax as for OPAL and APISIX**

The Keycloak component can be installed as follows:

```
helm install iam-keycloak oci://registry-1.docker.io/bitnamicharts/keycloak --version 21.4.4 \
  -n iam -f keycloak-values.yaml
```

### OPAL

The OPAL component can be installed as follows:

```
helm repo add permitio https://permitio.github.io/opal-helm-chart
helm repo update
helm install -f opal-values.yaml -n iam iam-opal permitio/opal --version 0.0.28
```

### APISIX

The APISIX component can be installed as follows:

```
helm repo add apisix https://charts.apiseven.com
helm repo update
helm install -f apisix-values-asf.yaml -n iam apisix apisix/apisix --version 2.9.0
```

Note that APISIX can also be installed as an ingress controller
and PEP on another cluster. In this case, a different namespace (default:
`ingress-apisix`) should be used.

### Further Setup

In order to make the IAM BB accessible from outside the cluster,
appropriate routes (aka ingresses) and TLS certificates need to
be configured.

This can be done by creating standard `Ingress` objects or
APISIX-specific `ApisixTls` and `ApisixRoute` objects. The latter allow
using APISIX-specific features and plugins that cannot be
configured using standard Ingress objects. Furthermore, they
allow separating the TLS configuration from the actual route
definitions.

#### TLS Configuiration

The TLS configuration depends on the issuers that are available in
your cluster. It requires a `Certificate` object and an `ApisixTls`
object per certificate. In the test environment, a global wildcard
certificate is used. This makes all routes within the scope of the
certificate support TLS without any further configuration.
Note that the separate `Certificate` object is needed, because Cert
Manager does not seem to honour `cert-manager.io/cluster-issuer`
annotations on an `ApisixTls` object.

Example from the test environment:

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

#### Route Configuration

A route need to be configured at least for Keycloak.
Optionally, further routes can be added for Open Policy Agent (OPA)
and any other services that need to be accessible from outside the
cluster.

The following is an example route definition for Keycloak. It includes
a workaround for a potential issue that causes redirects to address a
container port (9443) instead of the official HTTPS port (443).

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
    plugins:
      # Possible workaround for redirect-to-9443 problem that also works for HTTP
      - name: serverless-pre-function
        enable: true
        config:
          phase: "rewrite"
          functions:
            - "return function(conf, ctx) if tonumber(ngx.var.var_x_forwarded_port) > 9000 then ngx.var.var_x_forwarded_port = ngx.var.var_x_forwarded_port - 9000 end end"
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
[APISIX documentation](https://apisix.apache.org/docs/ingress-controller/concepts/apisix_route/#config-with-secretref).
