# Introduction

**Note**: This document is work in progress.

The documentation for the `Identity and Access Management` building block is organised as follows...

* **Introduction**<br>
  Introduction to the BB - including summary of purpose and capabilities.
* **Design**<br>
  Description of the BB design - including its subcomponent architecture and interfaces.
* **Administration**<br>
  Description of the installation and configuration and maintenance of the BB.
* **Usage**<br>
  How-tos and example configurations for usage by example.

## About `Identity and Access Management`

The IAM BB acts as a central contact point for authentication and authorization.
Some Components of the IAM BB can also be used as a template for local IAM-related
functionality of other BBs. 

## Capabilities

Summary of the capabilities:

- Provide Single Sign-on
- Support Identity Federations
- Fine grained policy enforcement
- Integration of existing PEP's and IAM's 
- Provision of a PEP template

For authentication, the IAM BB provides a central identity provider (IdP) that integrates
with a set of external IdPs and is based on Keycloak.
On the one hand, this allows users to authenticate via an external IdP of their
choice. On the other hand, BBs can simply integrate with the central IdP of the IAM
without having to care about the external IdPs.

Authorization capabilities are also provided by Keycloak through the OIDC protocol
and UMA flow. Simple authorization policies can be configured directly in Keycloak,
whereas more complex policy decisions are delegated to the Open Policy Agent (OPA),
which is also part of the IAM BB. Other BBs may also query the OPA directly in order
to obtain policy decisions without involving the complexity of a UMA flow.
