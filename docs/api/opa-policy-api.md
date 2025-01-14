# Policy Evaluation API

**Note:** This document is work in progress.

## General Considerations

Open Policy Agent offers two APIs for evaluating policy: the
[Data API](https://www.openpolicyagent.org/docs/latest/rest-api/#data-api)
and the [Query API](https://www.openpolicyagent.org/docs/latest/rest-api/#query-api).

The Data API allows retrieving documents in Json format. A document
may either be a static piece of data that has been stored in OPA
before, or the result of evaluating a policy. The API does not
explicitly distinguish these two cases, except that policies may
accept and take into account input data (called "input document"),
whereas this does not make sense for static documents. Each document
has a dedicated URI through which it can be retrieved. Retrieval is
possible via GET or POST requests, depending on whether an input
document shall be provided.

The Query API supports executing queries (expressed in Rego) without
directly addressing a specific document. This allows combining
documents in ways that are not foreseen by existing policy rules.

The Query API is mostly of interest for debugging and evaluation
purposes. For normal operation, we favour the Data API, because it
is easier to use and does not require knowledge of the Rego
language. Furthermore, we expect that the Data API provides enough
flexibility for policy evaluation.

## Interface between Keycloak and OPA

The Keycloak-OPA plugin uses OPA's Data API for evaluating policies.
Therefore, a policy URI must be provided for each configured OPA
policy. When evaluating a policy, the plugin sends a standardized
input document to the configured URI via a POST request and expects
OPA to return an output document that contains at least a defined
attribute that indicates permit or deny. Further attributes may be
present, but are ignored by the plugin, except that they may be
logged.

### Input Document

The Keycloak-OPA adapter constructs an input document with the
following information:

* User identity (same attributes as in JWT)
* Context attributes
* Associated permission incl. accessed resource, scopes and claims
  (if configured)

Example:

```
{
  "input": {
    "attributes": {
      "kc.client.id": ["demo-app"],
      "kc.client.network.host": ["10.42.4.0"],
      "kc.client.network.ip_address": ["10.42.4.0"],
      "kc.client.user_agent": ["lua-resty-http/0.16.1 (Lua) ngx_lua/10026"],
      "kc.realm.name": ["eoepca"],
      "kc.time.date_time": ["2025-01-14 11:58:59"]
    },
    "identity": {
      "attributes": {
        "acr": ["1"],
        "allowed-origins": ["/*"],
        "aud": ["eoapi", "account"],
        "auth_time": ["1736855939"],
        "azp": ["demo-app"],
        "email_verified": ["false"],
        "exp": ["1736856239"],
        "iat": ["1736855939"],
        "iss": ["https://iam-auth.apx.develop.eoepca.org/realms/eoepca"],
        "jti": ["837a959c-3772-4087-9dee-655436c0c180"],
        "kc.client.account.roles": ["manage-account", "manage-account-links", "view-profile"],
        "kc.client.eoapi.roles": ["stac_editor"],
        "kc.realm.roles": ["offline_access", "default-roles-eoepca", "uma_authorization", "user-premium", "user"],
        "preferred_username": ["eric"],
        "realm_access": ["{\"roles\":[\"offline_access\",\"default-roles-eoepca\",\"uma_authorization\",\"user-premium\",\"user\"]}"],
        "resource_access": ["{\"eoapi\":{\"roles\":[\"stac_editor\"]},\"account\":{\"roles\":[\"manage-account\",\"manage-account-links\",\"view-profile\"]}}"],
        "scope": ["openid profile email"],
        "session_state": ["540edce3-e5e6-417b-a3a2-35d2a42e38ce"],
        "sid": ["540edce3-e5e6-417b-a3a2-35d2a42e38ce"],
        "sub": ["060169bc-6794-46f3-8de9-24b61c2bd3a2"],
        "typ": ["Bearer"]
      },
      "id": "060169bc-6794-46f3-8de9-24b61c2bd3a2"
    },
    "permission": {
      "claims": {},
      "granted": false,
      "resource": {
        "attributes": {},
        "displayName": "",
        "id": "14fc813a-8efb-467d-bc90-0f928dcc60ea",
        "name": "all",
        "owner": "9c827707-a49d-4d4a-9a26-ae99cd8060d8",
        "ownerManaged": false,
        "resourceServer": {
          "allowRemoteResourceManagement": false,
          "clientId": "9c827707-a49d-4d4a-9a26-ae99cd8060d8",
          "id": "9c827707-a49d-4d4a-9a26-ae99cd8060d8"
        },
        "scopes": [], "uris": ["/*"]
      },
      "resourceServer": {
        "allowRemoteResourceManagement": false,
        "clientId": "9c827707-a49d-4d4a-9a26-ae99cd8060d8",
        "id": "9c827707-a49d-4d4a-9a26-ae99cd8060d8"
      },
      "scopes": []
    }
  }
}
```

Note that the `permission` section is only present if the `includePermission`
option is selected.  The `resource` section is only present if the
`includeResource` is also selected. The top-level `attributes`, `identity`
and `scopes` sections are always present.

### Output Document

As a response, the Keycloak-OPA plugin expects a simple document that
contains only a boolean attribute named `result`. The value `true`
is interpreted as "allow" and `false` is interpreted as "deny".

Example:

```
{
  "result": true
}
```

## Interface between APISIX and OPA

The policy interface between APISIX and OPA is defined by the
APISIX OPA plugin and is described
[here](https://apisix.apache.org/docs/apisix/plugins/opa/).

## External Interface to OPA

Other BBs may interface with OPA directly in order to evaluate
policies. In this case, the format of input and output documents
can in general be chosen freely. However, wherever possible,
the documents should be structured in a similar way as described
above. The following rules should be taken into account:

* A client that uses a rule that is also used through Keycloak
  must provide an input document in the format specified above.
  It may, however, omit attributes that it cannot provide or that
  it knows the policy rule will not evaluate.
* A client that uses a rule that is also used through Keycloak
  must be able to handle an output document as specified above.
* A client that uses a rule that is also used by APISIX must adhere
  to the input and output document format specified by the APISIX
  OPA plugin.
* A client that uses a dedicated rule may define its own input
  and output document formats. However, for similar information
  (e.g. a user identity) it should reuse the specified format(s)
  as far as possible.

Note: Due to the different output document formats, it is currently not
possible to create a policy rule that is suitable for both
Keycloak and APISIX out of the box. However, a separate wrapper rule
can be used to convert the output document of a rule if necessary.

On the long run, it is foreseen to extend the Keycloak-OPA plugin
so that it also supports the APISIX rule output format. Then this
format will be usable for all kinds of policy rules.
