# Architecture/ Overview

**Note**: This document is work in progress in an early state.
No guarantees are made regarding the consistency and correctness of its contents.

## IAM Building Block Overview

(TBD: Add figure and describe BB structure based on it.)

The IAM BB acts as a central contact point for authentication and authorization.
For authentication, it provides a central identity provider (IdP) that integrates
with a set of external IdPs and is based on Keycloak.
On the one hand, this allows users to authenticate via an external IdP of their
choice. On the other hand, BBs can simply integrate with the central IdP of the IAM
without having to care about the external IdPs.

Authorization capabilities are also provided by Keycloak through the OIDC protocol
and UMA flow. Simple authorization policies can be configured directly in Keycloak,
whereas more complex policy decisions are delegated to the Open Policy Agent (OPA),
which is also part of the IAM BB. Other BBs may also query the OPA directly in order
to obtain policy decisions without involving the complexity of a UMA flow.

## External Interfaces

### Exposed Interfaces

The IAM BB offers an interface for authentication based on OpenID Connect.
If required, SSO via SAML can also be supported.

Furthermore, the IAM BB supports authorization through the UMA flow and also provides
a REST interface for immediate policy evaluation.

Policies can be managed through a Git repository that is provided by the IAM BB.
However, it has not been decided yet if this Git repository will be exposed to the
outside world or if it will only be available for administrative use.

Protocols:

* OIDC
* SAML (optional)
* UMA
* OPA/ Rego (REST)
* Git (optional, tbc)

### Consumed Interfaces

The IAM BB supports delegating authentication to external IdPs via OpenID Connect.
If required, the SAML protocol can also be supported for this purpose.

Furthermore, the IAM BB can be configured to replicate policy-relevant data (e.g.
resource metadata) from arbitrary data sources into the policy engine (OPA).
This replication can take place via HTTP(S) or other protocols.

Protocols:

* OIDC
* SAML (optional)
* external data sources (HTTP(S), other protocols)

## Internal Interfaces

(TBD)

Protocols:

* Git (if not exposed, tbc)

## Required Resources

(TBD)

The following components have been foreseen so far:

* Keycloak
* OPAL Client (incl. OPA)
* OPAL Server
* Git
* PostgreSQL
* APISIX
* Keycloak-OPA adapter

## Static Architecture

(TBD)

## Use Cases

### Authentication-related Use Cases

#### IAM-UC-1: Delegated authentication (UC60, (UC61), UC62)

User stories:

* As a user, I want to authenticate with each platform using the same identity, so that I don't have to maintain multiple identities across many platforms (UC60)
* As an administrator, I want to uniquely identify each user (part of UC61)
* As a user, I want a federated solution to handle user attributes, so that multiple platforms can share these attributes and use them to inform authorisation and service provision decisions (UC62)

The IAM BB must be able to delegate authentication to commonly used external IdPs.
It must also be able to handle identity-related attributes provided by these IdPs,
use them for informing policy decisions and pass them to other BBs as required.

All in all, the IAM BB should ensure that users from any configured sources (IdPs)
are able to use services and resources of any connected BBs as far as access is granted
to them and no technical constraints (e.g. missing required attributes) prohibit this.

### Authorization-related Use Cases

#### IAM-UC-2: Delegated authorization

User stories:

* As a user, I want to be able to authorize services to access resources on my behalf (new)

This is especially relevant in the context of processing where the processing
system may need to retrieve a protected input product from the archive on
behalf of the user.

#### IAM-UC-3: Resource Sharing (UC63, UC64, UC65)

User stories:

* As a user, I want my resources to be accessible only by me and those that I selectively permit (UC63)
* As a user, I want to selectively share my resources with other users/groups (UC64)
* As a user, I want to receive authorised access to resources that have been shared with me (UC65)

### Miscellaneous Use Cases

#### IAM-UC-4: Policy Management (UC61)

User stories:

* As an administrator, I want to authorise access to the platform resources using policy rules that rely upon the user identity and associated attributes (part of UC61)
* As an administrator, I want to edit and update policy rules in a convenient and traceable way (new)

#### IAM-UC-5: Update Resource Information

User stories:

* As an administrator, I want to ensure that policy decisions are always based on recent information (new)
* As a user, I want new permissions granted to me to take effect without a noticeable delay (new)
* As a user, I want to be able to access new resources after registration without a noticeable delay if I have permission to do so (new)

Technical prerequisite for resource sharing.
This use case can be generalized to handle further information if required.

#### IAM-UC-6: IAM Administrative Access Control

User stories:

* As an administrator, I want to ensure that only privileged users can access administrative functionality of the IAM BB (new)

Security requirement.

### Ancillary Use Cases

For use case that are not foreseen to be implemented by the IAM BB itself,
but may affect it in some way, see section *Ancillary Use Cases* in `more-design.md`.
