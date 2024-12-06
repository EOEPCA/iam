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

* `openid-connect`: Triggers and handles authentication through OpenID Connect
* `authz-keycloak`: Handles authorization based on resources configured in Keycloak
  (adds PEP functionality)
* `opa`: Allows more fine-grained authorization based on OPA policies
  (directly accessing OPA, circumventing Keycloak)
* `redirect`: Can be used to configure an explicit redirect to HTTPS for individual
  routes (if redirect to HTTPS is not enforced by global configuration)
* `serverless-pre-function`: Used by the Keycloak route to implement a workaround
  for misguided redirects

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
  authentication, but still acts as a PEP and enforces authorization. This is
  useful for APIs where the caller is expected to obtain a JWT in advance.
* APISIX supports dividing routes into subroutes and applying different plugins
  to each of them. This is useful if there are open URIs (e.g. a main page or
  API documentation) in an otherwise protected application. It also allows
  mixing an API into an application that otherwise delegates authentication
  handling to APISIX.

### Simple route (pass-through)

This is an example of a simple route that forwards all traffic without applying
authentication or authorization:

```
apiVersion: apisix.apache.org/v2
kind: ApisixRoute
metadata:
  name: simple-route
  namespace: example-service-ns
  annotations:
    ingress.kubernetes.io/ssl-redirect: "true"
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
        # refSecret is an alternative way to specify sensitive information like the client secret. See APISIX example routes.
        #refSecret: full-route
      - name: authz-keycloak
        enable: true
        config:
          client_id: "example-client"
          client_secret: "example-client-secret"
          discovery: "https://iam-auth.apx.develop.eoepca.org/realms/eoepca/.well-known/uma2-configuration"
          lazy_load_paths: true
          # ssl_verify may have to be set to false in a test environment. Not recommended for production.
          ssl_verify: false
        #refSecret: full-route
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
        # refSecret is an alternative way to specify sensitive information like the client secret. See APISIX example routes.
        #refSecret: authn-only-route
```

### Authorization-only (API) route

The following route is suitable for protecting an API where the caller
obtains and presents a JWT. It therefore only involves authorization.

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
      - name: authz-keycloak
        enable: true
        config:
          client_id: "example-client"
          client_secret: "example-client-secret"
          discovery: "https://iam-auth.apx.develop.eoepca.org/realms/eoepca/.well-known/uma2-configuration"
          lazy_load_paths: true
          # ssl_verify may have to be set to false in a test environment. Not recommended for production.
          ssl_verify: false
        # refSecret is an alternative way to specify sensitive information like the client secret. See APISIX example routes.
        #refSecret: api-route
```

### Mixed route

The following example is a mixed route that leaves `/index.html`,
`/public` and `/public/*` unprotected within an otherwise
protected route. The path `/api/*` uses API protection
(authorization only), whereas all remaining paths use full
protection and combine authentication and authorization.

Furthermore, this route references the secret that stores the
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
      - name: authz-keycloak
        enable: true
        config:
          discovery: "https://iam-auth.apx.develop.eoepca.org/realms/eoepca/.well-known/uma2-configuration"
          lazy_load_paths: true
          # ssl_verify may have to be set to false in a test environment. Not recommended for production.
          ssl_verify: false
        refSecret: mixed-route
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
        refSecret: mixed-route
      - name: authz-keycloak
        enable: true
        config:
          discovery: "https://iam-auth.apx.develop.eoepca.org/realms/eoepca/.well-known/uma2-configuration"
          lazy_load_paths: true
          # ssl_verify may have to be set to false in a test environment. Not recommended for production.
          ssl_verify: false
        refSecret: mixed-route
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

Note that the `ApisixTls` object refers to secret that must contain
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
