# Declarative Keycloak Configuration

## Introduction

The IAM BB is designed to allow declarative setup of
all major configuration items. This setup is split into
a basic realm configuration represented by a
`KeycloakRealmImport` resource and an extended realm
configuration represented by Crossplane resources.
In principle, this allows defining the complete static
Keycloak configuration without ever using the Keycloak
Admin UI.

This document gives a short introduction in the aspects of
the setup that are part of the IAM BB itself and provides some
guidance regarding additional configuration to be contributed
for integrating other EOEPCA Building Blocks with the IAM. 

Platform Operators may also find this information helpful
for integrating custom components into their EOEPCA-based
platforms.

## Basic Realm Configuration

This section gives an overview of the basic configuration of the
EOEPCA realm. All items described here can be configured in
the `iam.keycloak.realm` section of the
[`values.yaml` file](https://github.com/EOEPCA/helm-charts-dev/blob/develop/charts/iam-bb/values.yaml)
of the IAM-BB Helm chart, which automatically builds a
`KeycloakRealmImport` resource from them.

If desired, this automatism can also be disabled, so that the
`KeycloakRealmImport` resource can be provided separately. 

### Base Settings

Basic realm settings that deviate from Keycloak's defaults can be
made in the `customSettings` subsection. If placeholders are used,
these can be defined in the `customPlaceholders` subsection.

The `customSettings` may contain anything that can be defined in
the `spec.realm` section of a `KeycloakRealmImport` resource,
except clients and users. Note that the `spec.realm` section
has exactly the same structure as a Keycloak realm export.
Thus it can basically be obtained by exporting a preconfigured
realm, reviewing and potentially reducing the result and
converting it to yaml.

The `values.yaml` file includes some (commented) example settings,
including e-mail settings that are typically required in every
setup. 

This is an example how a basic configuration including e-mail
settings could look like. Note that the SMTP password is taken
from a secret through a placeholder.

```yaml
iam:
  keycloak:
    configuration:
      realm:
        customPlaceholders:
          smtp_password:
            secret:
              name: eoepca-realm
              key: smtp_password
        customSettings:
          loginWithEmailAllowed: false
          smtpServer:
            starttls: "true"
            auth: "true"
            port: "587"
            host: "smtp.gmail.com"
            from: "eoepca@gmail.com"
            fromDisplayName: "EOEPCA Develop Cluster"
            user: "eoepca@gmail.com"
            password: ${smtp_password}
```

### Federated Identity Providers

Federated identity providers can be defined in the same way as
basic settings, i.e. in the
`iam.keycloak.configuration.realm.customSettings` section of the
`values.yaml` file.

The identity providers themselves are defined in a subsection named
`identityProviders`. Mappers can be defined in a subsection named
`identityProviderMappers`.

Here is an example configuration for a GitHub IdP. The client secret
is taken from a secret. Note that no mappers are required for GitHub.

```yaml
iam:
  keycloak:
    configuration:
      realm:
        customPlaceholders:
          github_client_secret:
            secret:
              name: eoepca-realm
              key: github_client_secret
        customSettings:
          identityProviders:
            - alias: "github"
              displayName: "GitHub"
              providerId: "github"
              enabled: true
              updateProfileFirstLoginMode: "on"
              trustEmail: false
              storeToken: false
              addReadTokenRoleOnCreate: false
              authenticateByDefault: false
              linkOnly: false
              hideOnLogin: false
              config:
                clientId: "a_github_client_id"
                acceptsPromptNoneForwardFromClient: "false"
                disableUserInfo: "false"
                filteredByClaim: "false"
                syncMode: "FORCE"
                clientSecret: "${github_client_secret}"
                caseSensitiveOriginalUsername: "false"
```

### Clients and Users

#### Crossplane Client

The Helm chart automatically creates a client with a service account
(M2M client) to be used by the Crossplane Keycloak Provider.
This client is included into the realm definition if
`iam.keycloak.configuration.provider.createServiceAccount` is set
to `true`. See the `iam.keycloak.configuration.provider` section
of the `values.yaml` file for additional configuration options.

#### Additional Clients and Users

Normally, the Crossplane client is the only one that should be part
of the realm definition. Any other clients and users should be
created via Crossplane.

However, if further clients or users have to be included into the
realm definition for some reason, they can be defined in the
`customClients` and `customUsers` subsections, respectively.

#### Master Admin Account

The Keycloak setup also creates a bootstrap Master Admin user.
This admin user is defined in the master realm and thus neither
part of the EOEPCA realm definition nor the Crossplane
configuration.

A username and password can be set in the
`keycloak-operator.keycloak.bootstrapAdmin` section of the
`values.yaml` file. If no password is set, the Keycloak
Operator automatically generates one and stores it in a secret.
See [Keycloak documentation](https://www.keycloak.org/operator/advanced-configuration#_admin_bootstrapping)
for more information.

## `iam-management` Namespace

The `iam-management` namespace is the preferred place for
Crossplane resources that link the IAM with other Building Blocks
and other (non-EOEPCA) components of a platform.

The `iam-bb-config` Helm chart prepares this namespace by adding
some predefined resources as a basis for further setup.
This section describes these resources.

Note that neither the `iam-bb` Helm chart nor the `iam-bb-config`
Helm chart automatically create the `iam-management` namespace.
If the `iam-bb-config` Helm chart is applied as a subchart of
the `iam-bb` Helm chart (recommended), the `iam-management`
namespace *must* be created explicitly in advance. If the
`iam-bb-config` Helm chart is applied separately, the
`--create-namespace` option can be used to create it.

### Crossplane Keycloak Provider Config

The Keycloak Provider Config acts as the main interface between
Keycloak and the Crossplane-based Keycloak configuration.

The Helm chart generates a resource of type `ProviderConfig`
(API `keycloak.m.crossplane.io`) with the fixed name
`keycloak-provider-config`. This provider config accesses
Keycloak as the Crossplane M2M client created during the
initial realm import.

All other Crossplane resources in the `iam-management` namespace
should refer to this provider as follows:

```yaml
spec:
  providerConfigRef:
    name: keycloak-provider-config
    kind: ProviderConfig
  # ...
```

### OPA Client

The Helm chart optionally creates a Keycloak client for OPA
as a Crossplane resource (if OPA is enabled and
`iam.keycloak.configuration.createClients` is set to `true`).
This client is used by the OPA route and is only relevant if
OPA should be accessible from outside the cluster.

The client can be taken as an example for client configuration.

### Miscellaneous Setup

Some secrets are required in both the main IAM namespace
(typically named `iam`) and the `iam-management` namespace.

If secrets are generated through sealed secrets, it is typically
easiest to generate two identical sealed secrets in both
namespaces.

Alternatively, External Secrets Operator can be leveraged to
promote secrets from the `iam` to the `iam-management`
namespace. The `iam-bb` Helm chart supports this by optionally
creating a Cluster Secret Store for the `iam` namespace.
The store is named `eso-store-iam`. It is created if
`iam.keycloak.configuration.createSecretStore` is set to `true`.
By default, the secret store can only be referenced from the
`iam-management` namespace. If required, however, it can also
be configured to be accessible from other namespaces, though
this is not recommended. 

The `iam-bb-config` Helm chart can optionally generate
`ExternalSecret` resources for the secrets that need to
be available in the `iam-management` namespace.

### EOEPCA Admin User

An EOEPCA Admin user is *not* created by the Helm chart, but it
is part of the IAM configuration on the demo cluster.
See [eoepca-admin.yaml](https://github.com/EOEPCA/eoepca-plus/blob/tmp-dd-to-rke2-merge/argocd/eoepca/iam/parts/eoepca-admin.yaml)
for details. *(**TODO:** Point link to `deploy-develop` branch after merge)*

The configuration picks up the existing `realm-admin` role as
a Crossplane resource, creates a user named `eoepca-admin` and
assigns the `realm-admin` role to it. This may serve as an example
how to define an admin user or a user in general.

Furthermore, the representation of the `realm-admin` role can be
used to create further users or clients with realm administration
privileges, e.g. for use by a separate Crossplane `ProviderConfig`
in a BB namespace.

## Crossplane-based Configuration

This section provides guidance and recommendations regarding the
Crossplane-based integration of the IAM BB with other Building
Blocks and non-EOEPCA components.

Crossplane resources for static setup should be defined in the
`iam-management` namespace. However, Building Blocks like
the Workspace BB that use them for dynamic configuration, should
create their dynamic resources in their own namespace(s). 

### Clients

Every Building Block or component that needs to integrate with
the IAM requires at least one client in Keycloak that represents
it.

Clients should generally be configured as restrictively as
possible. In particular they should

* restrict tokens to only the required scopes and audiences.
* disable `fullScopeAllowed`.
* disable authentication flows that are not required.
* maybe restrict redirect URIs and web origins by path (not
  always possible).

The following subsections provide some guidance how clients for
different purposes should be configured.

#### Frontend Clients

Frontend clients are public clients that are used for authentication
by a frontend application, typically running in a browser. This is
a rare case in EOEPCA.

A frontend application cannot guarantee confidentiality, which
implies that

* client authentication does not make sense, because the client
  credentials could easily be stolen anyway.
* frontend clients should generally require PKCE to ensure that
  tokens they request are not misdirected.
* frontend clients should only allow the standard flow.
* it is typically not very useful to address a frontend client as
  audience. So the normal case would be to address some backend
  client instead.

The following example illustrates how a frontend client can be
configured, including a mapper that adds a backend client to
the token audience:

```yaml
apiVersion: openidclient.keycloak.m.crossplane.io/v1alpha1
kind: Client
metadata:
  name: frontend-example-client
  namespace: iam-management
spec:
  providerConfigRef:
    kind: ProviderConfig
    name: keycloak-provider-config
  forProvider:
    clientId: frontend-example-client
    name: frontend-example-client
    realmId: eoepca
    accessType: PUBLIC
    baseUrl: "https://develop.eoepca.org/example-frontend"
    description: "Example Frontend Client"
    enabled: true
    fullScopeAllowed: false
    pkceCodeChallengeMethod: S256
    serviceAccountsEnabled: false
    standardFlowEnabled: true
    standardTokenExchangeEnabled: false
    validRedirectUris:
      - /*
    webOrigins:
      - /*
---
apiVersion: client.keycloak.m.crossplane.io/v1alpha1
kind: ProtocolMapper
metadata:
  name: audience-backend2
  namespace: iam-management
spec:
  providerConfigRef:
    kind: ProviderConfig
    name: keycloak-provider-config
  forProvider:
    name: audience-backend
    realmId: eoepca
    clientIdRef:
      name: frontend-example-client
    protocol: openid-connect
    protocolMapper: oidc-audience-mapper
    config:
      access.token.claim: 'true'
      included.client.audience: backend-example-client
```

#### Backend Clients

Backend clients are (typically confidential) clients that are
used for authentication by or on behalf of a backend application.
This is the typical case in EOEPCA.

This includes APISIX, which acts as a gateway and PEP on behalf
of a backend service. Therefore the backend service and
the APISIX route to it share a common client. Using separate
clients for the gateway and the backend is not easily possible
anyway, because APISIX's `openid-connect` plugin does not
support token exchange. Therefore we deliberately do not
distinguish between gateway clients and backend clients here.

A typical backend client should have the following properties:

* The client should be confidential, i.e. require client
  authentication. If it uses token exchange, it *must* be
  confidential.
* The client should not have standard token exchange enabled
  unless it actually requires it.
* Service account roles should be disabled.

##### Simple Backend Client Example

The following example shows how a simple backend client for a
leaf service (i.e., one that does not delegate to other services)
may be configured. Such a client does typically not require token
exchange.

```yaml
apiVersion: openidclient.keycloak.m.crossplane.io/v1alpha1
kind: Client
metadata:
  name: backend-leaf-example-client
  namespace: iam-management
spec:
  providerConfigRef:
    kind: ProviderConfig
    name: keycloak-provider-config
  forProvider:
    clientId: backend-leaf-example-client
    name: backend-leaf-example-client
    realmId: eoepca
    accessType: CONFIDENTIAL
    baseUrl: "https://develop.eoepca.org/example-backend"
    description: "Example Backend Client for a leaf service"
    enabled: true
    fullScopeAllowed: false
    pkceCodeChallengeMethod: S256
    serviceAccountsEnabled: false
    standardFlowEnabled: true
    standardTokenExchangeEnabled: false
    validRedirectUris:
    - /*
    webOrigins:
    - /*

```

##### Backend Client Example with Token Exchange

The following example shows how a backend client with token exchange
can be configured. Token exchange should be used by services that
delegate to other services in order to customize the scope and audience
of the token to send to the delegate service.

Note that the definition includes a an example client scope for
adding an audience to a token and attaches it to the client as
an optional scope. This is necessary, because audiences can indeed
be filtered directly, but they can only be added through a client
scope.

```yaml
piVersion: openidclient.keycloak.m.crossplane.io/v1alpha1
kind: Client
metadata:
  name: backend-delegating-example-client
  namespace: iam-management
spec:
  providerConfigRef:
    kind: ProviderConfig
    name: keycloak-provider-config
  forProvider:
    clientId: backend-delegating-example-client
    name: backend-delegating-example-client
    realmId: eoepca
    accessType: CONFIDENTIAL
    baseUrl: "https://develop.eoepca.org/example-backend2"
    description: "Example Backend Client with Token Exchange"
    enabled: true
    fullScopeAllowed: false
    pkceCodeChallengeMethod: S256
    serviceAccountsEnabled: false
    standardFlowEnabled: true
    standardTokenExchangeEnabled: true
    validRedirectUris:
    - /*
    webOrigins:
    - /*
---
apiVersion: openidclient.keycloak.m.crossplane.io/v1alpha1
kind: ClientScope
metadata:
  name: backend-leaf-example-client-audience
  namespace: iam-management
spec:
  providerConfigRef:
    kind: ProviderConfig
    name: keycloak-provider-config
  forProvider:
    name: backend-leaf-example-client-audience
    realmId: eoepca
---
apiVersion: client.keycloak.m.crossplane.io/v1alpha1
kind: ProtocolMapper
metadata:
  name: audience-backend-leaf-example-client
  namespace: iam-management
spec:
  providerConfigRef:
    kind: ProviderConfig
    name: keycloak-provider-config
  forProvider:
    name: audience-backend-leaf-example-client
    realmId: eoepca
    clientScopeIdRef:
      name: backend-leaf-example-client-audience
    protocol: openid-connect
    protocolMapper: oidc-audience-mapper
    config:
      access.token.claim: 'true'
      included.client.audience: backend-leaf-example-client
---
apiVersion: openidclient.keycloak.m.crossplane.io/v1alpha1
kind: ClientOptionalScopes
metadata:
  name: backend-delegating-example-client-opt-scopes
  namespace: iam-management
spec:
  providerConfigRef:
    kind: ProviderConfig
    name: keycloak-provider-config
  forProvider:
    realmId: eoepca
    clientIdRef:
      name: backend-delegating-example-client
    optionalScopes:
      - backend-leaf-example-client-audience
```

The client defined above is capable of performing token exchange.
It can exchange a token addressed to it (via `azp` or `aud`) for
a dedicated token that only has `backend-leaf-example-client` as
audience by requesting scope `backend-leaf-example-client-audience`
and restricting audience to `backend-leaf-example-client`.

#### Machine-to-Machine (M2M) Clients

A M2M Client is a client with an attached service account that
represents a service that acts as a M2M user.
A service uses such a client to authenticate against another
service that it intends to use.

In principle, a service account can be added to any confidential
client. However, for security reasons it is recommended to use
separate clients for authentication of users against a service
and for representing a service as a M2M user. A M2M Client and
its credentials should be kept as confidential as possible.

In particular, a M2M Client should only be used by the service
itself and not e.g. by an APISIX route that protects the service.
Notably this is important, because we do not use s separate
gateway client for APISIX. A combined M2M and backend client
would thus allow APISIX to act on behalf of the protected service
and thereby foil its protection function. 

The following example demonstrates how a simple M2M client can
be defined. The service account is created implicitly. The example
picks up the created service account as a `User` resource,
which can be referenced by further resources, e.g. to assign roles
or groups to it.

```yaml
apiVersion: openidclient.keycloak.m.crossplane.io/v1alpha1
kind: Client
metadata:
  name: m2m-example-client
  namespace: iam-management
spec:
  providerConfigRef:
    kind: ProviderConfig
    name: keycloak-provider-config
  forProvider:
    clientId: m2m-example-client
    name: m2m-example-client
    realmId: eoepca
    accessType: CONFIDENTIAL
    description: "Example M2M Client"
    enabled: true
    fullScopeAllowed: false
    serviceAccountsEnabled: true
    standardFlowEnabled: false
    standardTokenExchangeEnabled: false
---
# Optional: Pick up the service account user as a Crossplane resource
# for further customization
apiVersion: user.keycloak.m.crossplane.io/v1alpha1
kind: User
metadata:
  name: service-account-m2m-example-client
  namespace: iam-management
  annotations:
    crossplane.io/external-name: eoepca/service-account-m2m-example-client
spec:
  providerConfigRef:
    name: keycloak-provider-config
    kind: ProviderConfig
  managementPolicies:
    - Observe
  forProvider:
    username: service-account-m2m-example-client
    realmId: eoepca
```

### Users, Roles and Groups

#### Users

Users are usually managed dynamically and are thus not created
via Crossplane. An exception to this rule are example or admin users
that are part of a Building Block's infrastructure. Common examples
include:

* the standard demo users `alice`, `bob` and `eric`
* the EOEPCA realm admin user `eoepca-admin`

See [eoepca-admin.yaml](https://github.com/EOEPCA/eoepca-plus/blob/tmp-dd-to-rke2-merge/argocd/eoepca/iam/parts/eoepca-admin.yaml)
for an example that also demonstrates how a role can be assigned to a user.

#### Roles

Roles are usually directly related to platform capabilities and often
need to be evaluated by code. Thus they are static and should be
configured as Crossplane resources.

The following example demonstrates how to create a realm role and a
client role. The only difference is that a client role references a
client whereas a realm role does not.

```yaml
# Realm role
apiVersion: role.keycloak.m.crossplane.io/v1alpha1
kind: Role
metadata:
  name: example-realm-role
  namespace: iam-management
spec:
  providerConfigRef:
    name: keycloak-provider-config
    kind: ProviderConfig
  forProvider:
    realmId: eoepca
    name: example-realm-role
---
# Client role
apiVersion: role.keycloak.m.crossplane.io/v1alpha1
kind: Role
metadata:
  name: example-client-role
  namespace: iam-management
spec:
  providerConfigRef:
    name: keycloak-provider-config
    kind: ProviderConfig
  forProvider:
    realmId: eoepca
    name: example-client-role
    clientIdRef:
      name: backend-leaf-example-client
      policy:
        resolution: Required
```

Roles can be assigned to users or user groups using `Roles` resources
(API `user.keycloak.m.crossplane.io` or `group.keycloak.m.crossplane.io`,
respectively). An example can be found in
[eoepca-admin.yaml](https://github.com/EOEPCA/eoepca-plus/blob/tmp-dd-to-rke2-merge/argocd/eoepca/iam/parts/eoepca-admin.yaml).

#### Groups

User groups may be static or dynamic. Standard user groups for
predefined purposes should be configured as Crossplane resources.
Additionally, operators may create user groups for their own purposes
and structuring needs. Such groups are not reflected by Crossplane
resources.

The following examples demonstrates how to create a user group.

```yaml
apiVersion: group.keycloak.m.crossplane.io/v1alpha1
kind: Group
metadata:
  name: example-group
  namespace: iam-management
spec:
  providerConfigRef:
    name: keycloak-provider-config
    kind: ProviderConfig
  forProvider:
    realmId: eoepca
    name: example-group
```

Groups can be assigned to users using `Groups` resources
(API `user.keycloak.m.crossplane.io`).

### Picking Up Existing Objects

Sometimes it is necessary to create Crossplane resources for existing
objects, e.g., to assign a user to an existing group or add
a mapper to an existing client.

Crossplane has a mechanism for this purpose that is meanwhile also
supported by the Keycloak provider. The mechanism uses an annotation
named `crossplane.io/external-name`. The value of this annotation
is a reference to an existing object.

The Keycloak Provider interprets this reference as a path with up
to three components. The first path component is always the realm
name. So `eoepca` would reference the EOEPCA realm itself.

The second path component is the name of an object that is defined
in the realm, e.g. a user, group, realm role, client etc. The type
of the object is determined by the type of the annotated resource.
Examples:

* `eoepca/realm-management` refers to the realm management client
  of the EOEPCA realm.
* `eoepca/eric` refers to the example user `eric`
* More generally, `eoepca/foo` refers to an object named `foo` in
  the EOEPCA realm of the type represented by the resource being
  defined. Depending on the resource type, this may be a client,
  user, role, group or whatever. 

The third path component is used to address objects that belong
to a client. The second path component is always a client name
in this case.

Example: `eoepca/realm-management/manage-realm` refers to the
`manage-realm` client role of the `realm-management` client.

Usage examples for the `crossplane.io/external-name` annotation
can be found in
[eoepca-admin.yaml](https://github.com/EOEPCA/eoepca-plus/blob/tmp-dd-to-rke2-merge/argocd/eoepca/iam/parts/eoepca-admin.yaml).

Note that Crossplane replaces the value of the
`crossplane.io/external-name` annotation with the actual internal
ID of the referenced object during reconciliation. This may cause
inconsistencies if the resource is updated later. In ArgoCD it is
important to ensure that differences in this annotation are
ignored. Ideally, the annotation should never be updated.

Refer to [this pull request](https://github.com/crossplane-contrib/provider-keycloak/pull/206)
for further information and a discussion about the reference mechanism.

### Other Resources

Besides the resource types addressed in this document, the
Crossplane Keycloak Provider supports further resource types
that are less relevant in the context of EOEPCA. A complete
list of available resource types with documentation can be found
[here](https://marketplace.upbound.io/providers/crossplane-contrib/provider-keycloak).
