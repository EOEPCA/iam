# Keycloak

Keycloak is used as the central authentication and authorization component. 
Keycloak is a powerful open source platform for identity and access management (IAM) that offers a wide range of functions for managing authentication and authorization in an application or platform.
In the IAM BB we use it to map the following topics:

* Authentication and authorization
* Federated identity
    
Keycloak offers comprehensive authentication functions, including support for common protocols, such as OpenID Connect (OIDC), 
OAuth 2.0 and SAML (Security Assertion Markup Language). 
It enables secure and standardized authentication of users across different platforms.

## Federated Identities 

In addition, Keycloak supports the integration of identity federations, which means that it can integrate external identity providers (IdPs). 
By integrating identity federations, users can use their existing identities from external identity providers like ESA EOIAM, EGI, eduGain or ORCID to log in to the platform, which increases usability and simplifies the management of user identities. 
In addition, social logins for Google, GitHub etc. are conceivable. 

The external identity providers will be connected via standard protocols such as OpenID Connect (OIDC). 
It is also possible to integrate other protocols like SAML, WS-Federation, for example, but Keycloak offers its full feature set only in conjunction with OIDC. 
The integration of existing identity providers of utilization domains is also managed via the connection as an external identity provider.

## Integration with OPA

Keycloak allows the definition of fine-grained authorization, which can be combined with so called access control mechanisms (ACMs), like Attribute-based Access Control (ABAC) or Role-based Access Control (RBAC).
However, the OPA component shall be used as a state-of-the-art policy engine. 
Keycloak supports the integration of other ACMs through a so called Service Provider Interface (SPI). 
This interface is an extension point which also allows the integration of other policy engines. 

The IAM BB provides a Keycloak plugin for the integration of the OPA. 
More information see [Keycloak-OPA Adapter Plugin](../../design/components/auth-component/keycloak-opa-plugin.md))