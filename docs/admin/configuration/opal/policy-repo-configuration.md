# Policy Repository Configuration

## Introduction

The Open Policy Agent (OPA) takes decisions by evaluating policies.
These policies can be fed into OPA by different means.

The standard way for configuring policies in EOEPCA is via a Git
repository (GitOps-style). The Git repository is monitored by the
OPAL server, which triggers updates of OPA's internal policy cache
whenever policies change. The reference environment uses a [public
GitHub repository](https://github.com/EOEPCA/iam-policies), whereas
productive systems would rather keep their policies in a private,
well-protected repository.

In some restricted environments, the Git approach might not be viable.
In this case, there are several alternative ways to feed policies
into OPA:

* Policy bundles that are regularly fetched from a dedicated URL
  by OPAL
* Direct upload of policies into OPA via its Policy API
* Passing policies on OPA start-up

Note that the latter two ways directly access OPA, whereas policy
repositories and policy bundles are handled by OPAL, which
internally uses OPA's Policy API to synchronize policies with OPA. 

All these approaches are described in more detail in the following
sections. Additional information can be found in the
[OPAL documentation](https://docs.opal.ac/getting-started/running-opal/run-opal-server/policy-repo-location). 

## Public Policy Repository

The EOEPCA reference environment uses a public policy repository
hosted by GitHub. OPAL allows accessing public repositories via
HTTP or HTTPs.

The default configuration in the `values.yaml` file of the `iam-bb`
Helm chart looks like this:

```
opal:
  server:
    policyRepoUrl: https://github.com/EOEPCA/iam-policies.git
    policyRepoMainBranch: main
    pollingInterval: 300
```

This configures the OPAL server to poll for changes every 5 minutes.
Polling can be deactivated by setting `pollingInterval` to 0. In this
case, a webhook should be set up as described
[here](https://docs.opal.ac/getting-started/running-opal/run-opal-server/policy-repo-syncing/#option-2-using-a-webhook).
This requires the OPAL server or at least its `/webhook` endpoint to
be exposed via a public ingress.

The OPAL Helm chart does not provide a specific setting for the
webhook secret. It can be configured via `extraEnv` as shown here:

```
opal:
  server:
    policyRepoUrl: https://github.com/EOEPCA/iam-policies.git
    policyRepoMainBranch: main
    pollingInterval: 0
    extraEnv:
      OPAL_POLICY_REPO_WEBHOOK_SECRET: "the_webhook_secret"
```

## Private Policy Repository

For a production system, policies should be stored in a private
Git repository. OPAL is able to access private repositories using
the `ssh` protocol, but not via HTTP(S).

A private repository can be configured as follows:

```
opal:
  server:
    policyRepoUrl: ssh://user@myhost/path/to/repo
    policyRepoMainBranch: main
    pollingInterval: 300
    policyRepoSshKey: "ssh_key_with_newlines_replaced_with_underscores"
```

The SSH key is mandatory, because SSH does not support anonymous access.
More information about the format can be found
[here](https://docs.opal.ac/getting-started/running-opal/run-opal-server/policy-repo-location#optional-ssh-key-for-private-repos). 

## Policy Bundles

As an alternative to a Git repository, OPAL allows using a bundle server
as the policy source. A bundle server is a web server that serves a `.tar.gz`
file containing policy and data files, just like a Git repository would.

[This guide](https://docs.opal.ac/tutorials/track_an_api_bundle_server/)
describes how to set up OPAL to use a bundle server. Note that the OPAL
Helm chart does not provide specific settings for this. Thus most
settings have to be made in the `extraEnv` section. The following
example illustrates this:

```
opal:
  server:
    pollingInterval: 300
    extraEnv:
      POLICY_SOURCE_TYPE: API
      POLICY_BUNDLE_SERVER_TYPE: HTTP
      POLICY_BUNDLE_URL: "http://my-bundle-server/path/"
      POLICY_BUNDLE_SERVER_TOKEN_ID: "token_id_or_username"
      POLICY_BUNDLE_SERVER_TOKEN: "token_or_password"
```

Note that using webhooks instead of polling is supported in the same
way as for Git repositories. 

## OPA Policy API

Another alternative is to directly use OPA's
[Policy REST API](https://www.openpolicyagent.org/docs/latest/rest-api/#policy-api)
to upload policies into OPA. This circumvents OPAL, which is therefore
not strictly needed if only this approach is used.

The Policy API is available on OPA's standard port (typically `8181`)
beneath the path `/v1/policies/` without any additional configuration.

If the Policy API is used in parallel to the Git repo or a bundle server,
it must be made sure that they do not interfere with each other and not
manipulate the same policies.

## Passing Policies at Startup

In addition to the approaches described above, it is possible to pass
policies to OPA at startup. This approach should only be used for
policies that must be in place immediately when OPA is started.

This primarily applies to the authorization policies that restrict
access to OPA itself. These policies are contained directly in the
`values.yaml` file:

```
opal:
  client:
    opaStartupData:
      policy.rego: |
        # Simple example policy gives everyone read access to non-system documents
        # and only gives a root user full access.
        [...]
```

Additional files can be defined inline here if required.

"Real" (non-inline) files cannot be referenced directly from the
`values.yaml` file, and the OPAL Helm chart does not foresee a
standard way to mount additional volumes into the OPAL Client
container. So this requires alternative solutions like a custom
container image and/ or an enhanced Helm chart.
