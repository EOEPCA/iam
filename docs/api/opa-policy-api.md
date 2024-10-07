# Policy Evaluation API

**Note:** This document is work in progress.

## General Considerations

Open Policy Agent offers two APIs for evaluating policy: the Data API
and the Query API.

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
present, but are ignored by the plugin, except that thay may be
logged.

## Input Document

The Keycloak-OPA adapter constructs an input document with the
following information:

* User identity (same attributes as in JWT)
* Context attributes
* Associated permission incl. accessed resource, scopes and claims
  (if configured)

Example:

**TODO: Example**

```
...example...
```

### Output Document

**TODO**

```
...example...
```

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
* A client that uses a dedicated rule may define its own input
  and output document formats. However, for similar information
  (e.g. a user identity) it should reuse the specified format
  as far as possible.
  
  
Further information about the OPA can be found in the [OPA Documentation](https://www.openpolicyagent.org/docs/latest/)
