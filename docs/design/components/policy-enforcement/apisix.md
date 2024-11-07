# Policy Enforcement Component (APISIX)

Policy enforcement describes the process of enforcing a policy by routing all traffic, i.e. all requests and responses, through a Policy Enforcement Point (PEP). 
As all traffic to and from the BB must go through the PEP, the PEP can inspect it, redirect requests and effectively block unauthorized requests.
The PEP is part of or closely tied to the BB or the component it is protecting to make sure that no traffic can circumvent it, which is not easily done from outside the protected environment. This implies that the IAM BB is not able to provide a central PEP that other BBs could use, but it can provide central interfaces that the PEPs can use to outsource tasks related to authentication and authorization.

For the IAM BB, the APISIX Ingress Controller is combined with an APISIX API Gateway, which is optimized for traffic control, low latencies and has great support for authentication and authorization (including a dedicated interface module for OPA) and supports separation of authentication and authorization.

## APISIX

The IAM BB uses an APISIX Ingress Controller as its Policy Enforcement Point. As an additional use, this PEP acts as demonstrator and template for PEP functionality for other BBs. For the IAM itself, it serves the following purposes:

* It restricts administrative access to Keycloak, OPA and OPAL.
* It restricts access to OPA by other BBs.
* It blocks anonymous access to the IAM. However, it does not impose any limitations on the authentication flow, which explicitly deals with initially anonymous users.
