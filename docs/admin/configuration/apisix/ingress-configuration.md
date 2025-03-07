# Ingress Configuration

This chapter explains ingress configuration in conjunction with
the IAM BB and the APISIX ingress controller. It also provides some
examples for common scenarios.

## Route Configuration

By default, the IAM BB uses APISIX as an ingress controller. This section
describes the most common ways to configure an ingress that works together
with Keycloak to perform authentication and/or authorization.

APISIX allows configuring ingresses through a standard `Ingress` object.
However, this only allows creating standard ingresses that do not use
special features of APISIX.

If APISIX features need to be used (which is the case if authentication
and/or authorization handling is required), ingresses (which correspond to
"routes" in APISIX) should be configured using the `ApisixRoute` CRD
provided by APISIX. This allows using plugins that add special behaviour
to a route.

The following plugins are useful in conjunction with the IAM BB:

* `openid-connect`: Verifies, triggers and handles authentication through
  OpenID Connect
* `authz-keycloak`: Handles authorization based on resources configured in Keycloak
  (adds PEP functionality)
* `opa`: Allows more fine-grained authorization based on OPA policies
  (directly accessing OPA, circumventing Keycloak)
* `redirect`: Can be used to configure an explicit redirect to HTTPS for individual
  routes (normally not necessary, because redirect to HTTPS is enforced by a
  global configuration by default)
* `serverless-pre-function`: Can be used to manipulate headers passed to upstream
  services. Used by a global rule to work around wrong `X-Forwarded-Port` values.

### Routing Scenarios

The following example routes only use the `openid-connect` and `authz-keycloak`
plugins. They cover the following use cases:

* A route that includes neither of the two plugins passes through all traffic
  to the backend. This is useful if the backend entirely handles authentication
  and authorization itself or does not require any protection for some other reason.
* If a route includes both plugins, APISIX completely handles authentication and
  authorization on behalf of the backend, allowing the backend to ignore
  these aspects. APISIX still passes a JWT to the backend after authentication,
  which allows it to take into account the user's identity if needed.
* For a route with only the `openid-connect` plugin configured, APISIX only
  enforces authentication and passes down the JWT to the backend. This is
  useful if the backend performs authorization itself, but does not handle
  authentication.
* If a route only includes the `authz-keycloak` plugin, APISIX does not trigger
  authentication, but still acts as a PEP and enforces authorization. In principle,
  this is useful for APIs where the caller is expected to obtain a JWT in advance.
  Note, however, that using `authz-keycloak` without `openid-connect` is not
  recommended, because it does not provide proper feedback to the caller.
  Instead, for an API route the `openid-connect` plugin should be configured
  with `bearer_only` set to `true`, which causes it to only validate the
  incoming JWT.
* Instead of `authz-keycloak` (or even in addition to it), the `opa` plugin
  can be used for authorization. This allows delegating authorization decisions
  to OPA instead of Keycloak. This makes sense for authorization decisions
  that would require much individual configuration in Keycloak, but can also
  be taken easily by an OPA policy rule based solely on the information
  contained in the HTTP request (incl. the JWT).
* APISIX supports dividing routes into subroutes and applying different plugins
  to each of them. This is useful if there are open URIs (e.g. a main page or
  API documentation) in an otherwise protected application. It also allows
  mixing an API into an application that is otherwise configured for
  interactive use.

### Simple route (pass-through)

This is an example of a simple route that forwards all traffic without applying
authentication or authorization:

```
apiVersion: apisix.apache.org/v2
kind: ApisixRoute
metadata:
  name: simple-route
  namespace: example-service-ns
spec:
  http:
  - name: simple-http-route
    backends:
    - serviceName: example-service
      servicePort: 80
    match:
      hosts:
      - simple-example.apx.develop.eoepca.org
      paths:
      - "/*"
```

### Fully protected route (authentication and authorization)

The following route involves both authentication and authorization:

```
apiVersion: apisix.apache.org/v2
kind: ApisixRoute
metadata:
  name: full-route
  namespace: example-service-ns
spec:
  http:
  - name: full-http-route
    match:
      hosts:
        - full-example.apx.develop.eoepca.org
      paths:
        - "/*"
    backends:
      - serviceName: example-service
        servicePort: 80
    plugins:
      - name: openid-connect
        enable: true
        config:
          client_id: "example-client"
          client_secret: "example-client-secret"
          access_token_in_authorization_header: true
          discovery: "https://iam-auth.apx.develop.eoepca.org/realms/eoepca/.well-known/openid-configuration"
        # secretRef is an alternative way to specify sensitive information like the client secret. See APISIX example routes.
        #secretRef: full-route
      - name: authz-keycloak
        enable: true
        config:
          client_id: "example-client"
          client_secret: "example-client-secret"
          discovery: "https://iam-auth.apx.develop.eoepca.org/realms/eoepca/.well-known/uma2-configuration"
          lazy_load_paths: true
          # ssl_verify may have to be set to false in a test environment. Not recommended for production.
          ssl_verify: false
        #secretRef: full-route
```

### Authentication-only route

This route triggers authentication, but leaves authorization to the backend:

```
apiVersion: apisix.apache.org/v2
kind: ApisixRoute
metadata:
  name: authn-only-route
  namespace: example-service-ns
spec:
  http:
  - name: authn-only-http-route
    match:
      hosts:
        - authn-only-example.apx.develop.eoepca.org
      paths:
        - "/*"
    backends:
      - serviceName: example-service
        servicePort: 80
    plugins:
      - name: openid-connect
        enable: true
        config:
          client_id: "example-client"
          client_secret: "example-client-secret"
          access_token_in_authorization_header: true
          discovery: "https://iam-auth.apx.develop.eoepca.org/realms/eoepca/.well-known/openid-configuration"
        # secretRef is an alternative way to specify sensitive information like the client secret. See APISIX example routes.
        #secretRef: authn-only-route
```

### Authorization-only (API) route

The following route is suitable for protecting an API where the caller
obtains and presents a JWT. It therefore only involves authorization.

The `openid-connect` plugin is also present, but configured with
`bearer_only` set to `true`. It only validates the incoming JWT.
In case of failure, it ensures a proper (401) response with an
appropriate `WWW-Authenticate` header instead of triggering an
interactive authentication flow.

```
apiVersion: apisix.apache.org/v2
kind: ApisixRoute
metadata:
  name: api-route
  namespace: example-service-ns
spec:
  http:
  - name: api-http-route
    match:
      hosts:
        - api-example.apx.develop.eoepca.org
      paths:
        - "/*"
    backends:
      - serviceName: example-service
        servicePort: 80
    plugins:
      - name: openid-connect
        enable: true
        config:
          client_id: "example-client"
          client_secret: "example-client-secret"
          access_token_in_authorization_header: true
          # Only validate the JWT and report 401 on failure; do not trigger authN flow
          bearer_only: true
          discovery: "https://iam-auth.apx.develop.eoepca.org/realms/eoepca/.well-known/openid-configuration"
        # secretRef is an alternative way to specify sensitive information like the client secret. See APISIX example routes.
        #secretRef: api-route
      - name: authz-keycloak
        enable: true
        config:
          client_id: "example-client"
          client_secret: "example-client-secret"
          discovery: "https://iam-auth.apx.develop.eoepca.org/realms/eoepca/.well-known/uma2-configuration"
          lazy_load_paths: true
          # ssl_verify may have to be set to false in a test environment. Not recommended for production.
          ssl_verify: false
        #secretRef: api-route
```

### Route with OPA-based authorization

The following route uses the `opa` plugin for authorization instead of
the `authz-keycloak` plugin. Otherwise it is similar to the fully
protected route example.

Note that the configuration of the `opa` plugin just refers to the OPA
service and the policy rule to be used. The actual authorization decision
is taken by the policy rule based on the request data passed by the
`opa` plugin.

```
apiVersion: apisix.apache.org/v2
kind: ApisixRoute
metadata:
  name: opa-authz-route
  namespace: example-service-ns
spec:
  http:
  - name: opa-authz-http-route
    match:
      hosts:
        - opa-authz-example.apx.develop.eoepca.org
      paths:
        - /*
    backends:
      - serviceName: example-service
        servicePort: 80
    plugins:
      - name: openid-connect
        enable: true
        config:
          client_id: "example-client"
          client_secret: "example-client-secret"
          access_token_in_authorization_header: true
          discovery: "https://iam-auth.apx.develop.eoepca.org/realms/eoepca/.well-known/openid-configuration"
        # secretRef is an alternative way to specify sensitive information like the client secret.
        #secretRef: opa-authz-route
      - name: opa
        enable: true
        config:
          host: http://iam-opal-opal-client:8181
          policy: eoepca/workspace/wsui
```

### Mixed route

The following example is a mixed route that leaves `/index.html`,
`/public` and `/public/*` unprotected within an otherwise
protected route. The path `/api/*` uses API protection
(authorization only), whereas all remaining paths use full
protection and combine authentication and (Keycloak-based)
authorization.

Furthermore, this route references a secret that stores the
client credentials. See next section for more details,
including an example secret.

```
apiVersion: apisix.apache.org/v2
kind: ApisixRoute
metadata:
  name: mixed-route
  namespace: example-service-ns
spec:
  http:
  - name: public-http-route
    backends:
      - serviceName: example-service
        servicePort: 80
    match:
      hosts:
        - mixed-example.apx.develop.eoepca.org
      paths:
        - /*
      exprs:
        - subject:
            scope: Path
          op: RegexMatch
          value: "^/(index.html|public(/.*)?)"
  - name: api-http-route
    backends:
      - serviceName: example-service
        servicePort: 80
    match:
      hosts:
        - mixed-example.apx.develop.eoepca.org
      paths:
        - /api/*
    plugins:
      - name: openid-connect
        enable: true
        config:
          access_token_in_authorization_header: true
          # Only validate the JWT and report 401 on failure; do not trigger authN flow
          bearer_only: true
          discovery: "https://iam-auth.apx.develop.eoepca.org/realms/eoepca/.well-known/openid-configuration"
        secretRef: mixed-route
      - name: authz-keycloak
        enable: true
        config:
          discovery: "https://iam-auth.apx.develop.eoepca.org/realms/eoepca/.well-known/uma2-configuration"
          lazy_load_paths: true
          # ssl_verify may have to be set to false in a test environment. Not recommended for production.
          ssl_verify: false
        secretRef: mixed-route
  - name: default-http-route
    backends:
      - serviceName: example-service
        servicePort: 80
    match:
      hosts:
        - mixed-example.apx.develop.eoepca.org
      paths:
        - /*
    plugins:
      - name: openid-connect
        enable: true
        config:
          access_token_in_authorization_header: true
          discovery: "https://iam-auth.apx.develop.eoepca.org/realms/eoepca/.well-known/openid-configuration"
        secretRef: mixed-route
      - name: authz-keycloak
        enable: true
        config:
          discovery: "https://iam-auth.apx.develop.eoepca.org/realms/eoepca/.well-known/uma2-configuration"
          lazy_load_paths: true
          # ssl_verify may have to be set to false in a test environment. Not recommended for production.
          ssl_verify: false
        secretRef: mixed-route
```

### Configuring client credentials as a secret

The examples above (except the mixed route example)
contain client credentials in clear text, which is not
really suitable for real-world use.
Therefore APISIX allows externalizing any attributes
of plugin configurations to a secret. This can and should
be used to externalize the `client_id` and `client_secret`
attributes.

The secret is referenced from the plugin configuration
by the `secretRef` attribute. The mixed route
example above demonstrates the use of `secretRef`.

It is recommended to name the secret like the route it
is used by. This is an example what the secret referenced
by the mixed route example could look like:

```
apiVersion: v1
data:
  client_id: "ZXhhbXBsZS1jbGllbnQ="
  client_secret: "ZXhhbXBsZS1jbGllbnQtc2VjcmV0"
kind: Secret
metadata:
  # Secret name should match route name.
  name: full-route
  namespace: example-service-ns
type: Opaque
```

### Reusing plugin configurations

Sometimes plugins need to be applied in multiple places with
the same configuration. For this scenario, APISIX provides the
`ApisixPluginConfig` CRD that allows defining the plugin
configuration once in a central place and referencing it from
routes where needed. This can eliminate a lot of redundancy.

Documentation about this feature can be found [here](https://apisix.apache.org/docs/ingress-controller/concepts/apisix_plugin_config/).

This is an example plugin config that provides a preconfigured
`openid-connect` plugin:

```
apiVersion: apisix.apache.org/v2
kind: ApisixPluginConfig
metadata:
  name: example-plugin-config
  namespace: example-ns
spec:
  plugins:
    - name: openid-connect
      enable: true
      config:
        access_token_in_authorization_header: true
        bearer_only: false
        discovery: https://iam-auth.develop.eoepca.org/realms/eoepca/.well-known/openid-configuration
      secretRef: example-plugin-config
```

The configuration can be referenced from a route as follows:
```
[...]
spec:
  http:
  - name: some-subroute
    plugin_config_name: example-plugin-config
    # Additional plugins can be specified as usual if needed:  
    #plugins: [...]
[...]
```

A positive side effect of using `ApisixPluginConfig` is that the plugin
configuration is instantiated only once. This also implies that each
plugin is initialized only once. This may be important if a plugin
(e.g., `openid-connect`) generates encryption keys during its initialization
process, because it ensures that the same keys are used in all places
where the plugin configuration is referenced. In case of the
`openid-connect` plugin this makes session keys reusable across
multiple routes, which would not be the case if the plugin
occurrences were configured separately.

Note that the `plugins` section of `ApisixPluginConfig` supports the
same attributes as the `plugins` section of `ApisixRoute`, including
`secretRef`. So an existing plugin configuration can simply be moved
to an `ApisixPluginConfig` object, which can then be referenced from
the original location via `plugin_config_name`.

### Upstream configuration

The example routes above simply refer to the upstream services to
address through the `backends` section. This is sufficient in many cases.
However, the `backends` section does not provide full control over
all aspects of an upstream connection. E.g., it only supports plain
HTTP connections and does not allow using TLS encryption out of the
box.

Advanced upstream configuration is possible using an `ApisixUpstream`
object that is associated with a service by its name (i.e., the upstream's
name must match the service name). It allows configuring several aspects
of the connection to an upstream service as documented
[here](https://apisix.apache.org/docs/ingress-controller/concepts/apisix_upstream/).

As an example, the upstream protocol can be set through the `scheme`
attribute. Setting `scheme` to `https` makes the connection use TLS.

```
apiVersion: apisix.apache.org/v2
kind: ApisixUpstream
metadata:
  name: example-service
spec:
  scheme: https
```

Note that there are currently some pitfalls when using `ApisixUpstream`:
* The value `https` is only supported by the global `scheme` attribute, 
  but not by `portLevelSettings[].scheme`. This seems to be a bug in the
  APISIX Ingress Controller.
* Apparently, after an `ApisixUpstream` is added or modified, all routes
  that are affected by it need to be touched (i.e., modified) in order
  for the upstream configuration to take effect. This seems to be a bug
  in the APISIX Ingress Controller, which might be a consequence of the
  next point.
* Synchronization warnings related to `ApisixUpstream` may appear in
  the ingress controller logs as described in
  [this issue](https://github.com/apache/apisix-ingress-controller/issues/1996).

### Special cases

This section describes relevant special configuration options beyond the
examples above.

#### WebSocket routing

By default, APISIX routes do not allow WebSocket connections.
In order to enable them, the `websocket` attribute must be set to
`true` on the subroute level, e.g.:

```
[...]
spec:
  http:
  - name: websocket-http-route
    websocket: true
[...]
```

#### Method-dependent routing

In some cases, especially when protecting REST APIs, it is necessary
to allow or block traffic based on the HTTP method used.

Subroutes can be statically restricted to certain HTTP methods by
adding the `methods` attribute to the `match` section of the subroute
specification as follows:
```
[...]
spec:
  http:
    - match:
        methods:
        - GET
        - POST
[...]
```

There is an alternative, more dynamic way to restrict the use of HTTP
methods. The `authz-keycloak` plugin is able to add the HTTP method
to the request URI as a scope. This allows checking the request method
along with the request URI dynamically in Keycloak. In order to activate
this, the `http_method_as_scope` attribute must be set to `true`.
The `lazy_load_paths` attribute should also be set to `true`in this case,
as shown below:

```
[...]
spec:
  http:
  - plugins:
      - name: authz-keycloak
        config:
          lazy_load_paths: true
          http_method_as_scope: true
[...]
```

Furthermore, OPA policy rules called via the `opa` plugin also have
access to the request method and can make decisions based on it.

#### Obtaining an offline token

Some BB services need to make calls to other BBs or external services
on behalf of the user outside an existing user session (typically in
case of deferred or scheduled tasks). In order to do this, they need
to obtain and store an offline token.

The recommended way to obtain the offline token is a dedicated route
for a single endpoint that requests the `offline_access` scope.
Whenever this endpoint is accessed within a session that does not
already have an offline token, the `openid-connect` plugin requests
one and stores it locally. It then passes the offline token to the
backend service in the `X-Refresh-Token` header.

Hence, in order to obtain an offline token, a service has to
* make the user agent access the configured endpoint, e.g. through a
  redirect, link or form submission, and
* intercept the call to the endpoint, read the token from the
  `X-Refresh-Token` header and store it for later use, and
* return some appropriate content that should include a notification
  to the user that an offline token has been retrieved and stored.

In addition to requesting the `offline_access` scope, the route for
the endpoint must be configured to populate the `X-Refresh-Token`
header as shown by the following example:

```
kind: ApisixRoute
metadata:
  name: authn-only-route
  namespace: example-service-ns
spec:
  http:
  - name: offline-token-retrieval-route
    match:
      hosts:
        - authn-only-example.apx.develop.eoepca.org
      # Only configure offline token retrieval for a dedicated path (no wildcards)
      paths:
        - /get_offline_token
    backends:
      - serviceName: example-service
        servicePort: 80
    plugins:
      - name: openid-connect
        enable: true
        config:
          client_id: "example-client"
          client_secret: "example-client-secret"
          access_token_in_authorization_header: true
          discovery: "https://iam-auth.apx.develop.eoepca.org/realms/eoepca/.well-known/openid-configuration"
          # Request an offline token instead of a refresh token.
          scope: openid email profile offline_access
          # Pass the offline token to the backend via the X-Refresh-Token header.
          set_refresh_token_header: true
```

## TLS Configuration

A standard `Ingress` combines both the routing and the TLS configuration.
APISIX, however, provides separate CRDs for routing and TLS handling.
While routes are configured using `ApisixRoute` CRDs, TLS mappings are
configured separately using CRDs of type `ApisixTls`. This adds some
flexibility in that it allows using a single TLS (wildcard) certificate
for multiple routes without having to repeat the configuration for every
single route. It also allows using different certificates for a single
route, though this is rarely useful.

A TLS certificate is configured in APSIX as an `ApisixTls` object.
The following example configures a common wildcard TLS certificate
that is used for `*.apx.develop.eoepca.org`. This allows defining
routes for arbitrary subdomains of `apx.develop.eoepca.org` without
having to care about TLS certificates.

```
apiVersion: apisix.apache.org/v2
kind: ApisixTls
metadata:
  name: example-wildcard-tls
  namespace: ingress-apisix
spec:
  hosts:
    - "*.apx.develop.eoepca.org"
  secret:
    name: example-wildcard-tls
    namespace: iam
```

Note that the `ApisixTls` object refers to a secret that must contain
the certificate. The secret must either be created manually or
managed through a `Certificate` object. It the latter case, it
can be created and refreshed automatically using CertManager.

This is an example `Certificate` object that generates the
wildcard certificate used above:

```
# Example wildcard certificate for APISIX ingress
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: apx-wildcard-cert
  namespace: ingress-apisix
spec:
  secretName: example-wildcard-tls
  duration: 2160h # 90d
  renewBefore: 360h # 15d
  isCA: false
  usages:
    - server auth
    - client auth
  dnsNames:
    - "*.apx.develop.eoepca.org"
  issuerRef:
    name: example-dns-clusterissuer
    kind: ClusterIssuer
```

Note that the `ApisixTls`, `Secret` and `Certificate` objects
must reside in the namespace (here: `ingress-apisix`) in which
APISIX is deployed.
