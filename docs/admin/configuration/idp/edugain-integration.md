# Integration with eduGAIN

**Note:** This document is still in draft state and partially incomplete.

## Introduction

### What is eduGAIN?

EduGAIN is an interfederation service that establishes trust between
entities (SPs and IdPs) of its member federations. However, eduGAIN
is not a federation itself. Hence only federations can be a direct
member of eduGAIN.

Entities can only join eduGAIN via one of its member federations,
which are typically national federations for research and educational
entities. In most cases, there is exactly one such federation per
country. Some countries, however, do not have a national federation
that is an eduGAIN member. 

The role of eduGAIN is to make IdPs in any given member federation
interoperable with SPs from any other member federation. Thus,
at least in theory, a user authenticated at any IdP that is part of
eduGAIN may use any SP that is registered in eduGAIN. In practice,
however, SPs often limit the set of IdPs they accept, or they
require a certain level of assurance that not every IdP can
guarantee or attributes that not every IdP can deliver. Likewise,
IdPs typically only accept authentication requests from known SPs
or SPs that are run by trusted organizations. 

Note that not all entities of a member federation are automatically
part of eduGAIN. For each single entity, it is an individual decision
whether it should be exposed to eduGAIN or not.

### Challenges

#### IdP discovery

EduGAIN meanwhile comprises several thousand IdPs and SPs, which do
not necessarily know anything about one another. This gap is bridged
by a discovery service that allows users to discover and select the
IdP they want to use to log in. Usually this is the IdP of their
home organization.

The discovery process is triggered by the SP when it requires the
user to log in. Thus the SP determines which discovery service to
use. This can be a custom discovery service or one provided by an
external entity like the eduGAIN member federation the SP is member
of. A custom discovery service allows the SP to limit the selectable
IdPs to those it actually accepts. In contrast, a federation-provided
discovery service usually offers all IdPs of its federation,
eduGAIN or both.

#### Keycloak limitations

Keycloak cannot support eduGAIN directly, because it requires each
federated IdP to be configured separately and explicitly. Thus, it
does not support dynamic IdP discovery.
Furthermore, Keycloak assigns an individual endpoint URL to each single
federated IdP, whereas eduGAIN relies on a single well-known assertion
consumer service endpoint that is used by all IdPs.

This can be solved by putting an SP-IdP proxy like
[SATOSA](https://daasi.de/en/satosa-a-modular-proxy/) in
front of Keycloak. The proxy appears to Keycloak as a single IdP
and integrates with eduGAIN as a SP. It also initiates IdP selection.
The proxy can be connected to Keycloak through OIDC or SAML.
EOEPCA+ uses OIDC as its standard authentication protocol, and
thus it is also preferred here for consistency.

Some national federations like DFN AAI also provide an OIDC proxy
that takes the role of the SP-IdP proxy. If such a proxy is available
it can be used instead of a custom SP-IdP proxy, at least if there
are no specific requirements on the discovery process and required
attributes.

...

#### Attribute Mapping

IdPs and SPs need a common understanding on the attributes they
provide or consume, respectively. Fortunately, eduGAIN addresses
this requirement by specifying a common set of attributes that
IdPs must or may provide and that SPs may expect. This set is
based on standard X.500/LDAP attributes and the `eduPerson` and
`SCHAC` schemas. However, most of these attributes are optional.
Additionally, the set of attributes has evolved over time, and so
not all IdPs necessarily support all attributes.

Most IdPs only release a minimal set of attributes (possibly none
except a transient user identifier) to SPs by default. If an SP
requires additional attributes, these need to be released
explicitly on IdP side. Thus, though eduGAIN establishes a general
pairwise trust relationship between all of its IdPs and and all
of its SPs, it does not ensure effortless pairwise
interoperability by itself.

TODO: Mapping in SATOSA

TODO: Subject identifier problem ->
[Identifier attributes](https://wiki.geant.org/spaces/eduGAIN/pages/121348100/Identifier+Attributes)

SATOSA provides a set of standard mappings for the most relevant
attributes.


* subject identifier
* eduPersonPrincipalName

...

### Integration Approaches

EduGAIN is based on the SAML standard. There are intentions to migrate
EduGAIN to OpenID Connect and OpenID Federation, but these are still
in an early state. The OIDC Proxy of DFN AAI is a first step into this
direction.

Thus SAML is the only portable way to integrate with eduGAIN, because
only SAML is guaranteed to be supported by all participating federations.
Therefore this approach has been chosen for EOEPCA. The IAM BB of
the EOEPCA Reference Environment will be integrated into the DFN AAI
Test federation as a SAML SP via an SP-IdP proxy. When this has been
done, it can be promoted to DFN AAI and/or eduGAIN.

Some federations provide their own SP-IdP proxy to which external
entities can attach. E.g., DFN AAI provides an OIDC proxy that
allows SPs to integrate through OpenID Connect. This simplifies
integration a lot, but also comes with a few drawbacks:

* From the eduGAIN or DFN AAI point of view, the proxy appears as a
  single SP. Thus, IdP cannot distinguish between different services
  that use the proxy, but either have to accept them all or none of
  them.
* From the service's point of view, the proxy appears as a single IdP.
  Furthermore, the proxy handles IdP discovery internally, supporting
  a fixed set of IdPs. Thus, the SP cannot restrict the set of IdPs
  that it accepts upfront, but only derive it after authentication from
  the token claims.
* The supported set of attributes of the proxy is fixed. Thus, services
  that use the proxy cannot request custom attributes from IdPs.

In the long run, eduGAIN plans to support OpenID Federation. Some
federations like DFN AAI participate in pilot projects that support
this objective. When full OpenID Federation support is reached,
compatible services will be able to integrate with eduGAIN directly
using OIDC if their SP software supports OpenID Federation.
Note that Keycloak does not support OpenID Federation yet, so basically
the same limitations as for SAML apply.

### Example Setup

**TODO:** Add figure

The EOEPCA+ Development Environment is integrated with eduGAIN via DLR
and DFN AAI via two ways:

* An SP-IdP proxy in the EOEPCA+ Development Environment: This proxy is
  only attached to the DFN AAI Test Federation. (done)
* An SP-IdP proxy in the DLR EOC UMS Environment (optional): Initially,
  this proxy should also be attached to the DFN AAI Test Federation,
  but it is foreseen to publish it to eduGAIN as well, at least
  temporarily for demonstration. (open)

In both cases, the proxy is based on SATOSA.

In parallel, DLR are integrating some of their services with eduGAIN
via the DFN AAI OIDC Proxy. This integration approach shall is also
documented as an option for EOEPCA+.

The integration of the EOEPCA Development Environment with the DFN AAI
Test Environment via an SP-IdP proxy in the EOEPCA Development
Environment is finished. The respective SATOSA setup can be found
[here](https://github.com/EOEPCA/eoepca-plus/tree/deploy-develop/argocd/eoepca/iam/parts/satosa). 


**TODO:** Describe relevant parts here

### Alternative: Integration Using Existing SP-IdP Proxy

If the selected national federation provides a preconfigured
SP-IdP proxy, it is an option to use it instead of setting up
and registering a custom proxy.

DFN AAI provides the "DFN AAI OIDC Proxy" that allows integrating
with DFN AAI and eduGAIN in the same way as with any OIDC IdP,
eliminating the complexity of SAML.

**TODO:** Add link to proxy docs

However, using this proxy (or an equivalent one of another
federation) also has its downsides:

* The proxy only supports a fixed set of attributes. It is not
  possible to use attributes beyond this set.
* The proxy appears to eduGAIN as a single SP. An IdP is therefore
  unable to identify and distinguish the proxy's clients, because
  it does not know anything about them. If a client requires
  additional attributes from an IdP, the IdP must be configured
  to release them to the proxy, which implicitly releases them to
  all clients of the proxy. This is problematic from a data
  protection point of view, because effectively it causes the
  IdP to lose control over its data.

### Looking Ahead: OpenID Federation

At present, eduGAIN is entirely based on SAML. However, it is
envisaged to also support OIDC natively in eduGAIN and maybe even
replace SAML with OIDC on the long run.

OIDC alone is insufficient to handle the complexity of eduGAIN
as it is based on mutual trust. Therefore it is foreseen to
implement OpenID Federation, which allows establishing trust
between an arbitrary set of IdPs and SP and can replace the
SAML metadata distribution infrastructure.

DFN AAI is involved in a pilot project that aims at evaluating
and supporting OpenID Federation for eduGAIN. This project is
still in an early stage though. So it may take a while until
OpenID Federation support is actually supported by a
significant number of eduGAIN entities.

Furthermore, Keycloak does not yet support OpenID Federation.
Thus, even if it were already available, we would currently
not be able to leverage it directly.

**TODO:** Add links (OpenID Fed., OIDC pilot project)

### Resources

**TODO:** Where to look for examples and templates...

## Preparation and Legal Aspects

### Check Prerequisites

Only educational and research organizations may join eduGAIN via one
of its member federations.
...

### Select National Federation

Integration with eduGAIN requires membership in a national federation
that participates in eduGAIN. Organisations that belong to a certain
country would typically choose the national federation of their home
country.

However, for international organisations like ESA, it may
be more difficult to choose an appropriate federation. Such
organisations should first contact the national federation of the
country in which their headquarters are located. If this federation
rejects membership, national federations of other countries with
some relationship to the organisation should be tried.

As an alternative, a collaboration with some national organisation
can allow access to a national federation. In the case of the
EOEPCA+ project, we collaborate with DLR, which is a member of
DFN AAI.

### Join Federation

The process to join a national federation may differ between federations.
Generally you need to sign some kind of agreement with the
federation provider and assure that you will adhere to their regulations. 

These regulations typically cover aspects like data protection and, for
an IdP, reliability of the information provided by that IdP. They also
include a code of conduct.

The regulations imposed by the eduGAIN member federations comprise at
least the general regulations required by eduGAIN (**TODO: Link?**),
but may include further obligations.

E.g., the minimum requirements for data protection differ from
country to country. National federations must follow these requirements
and thus may have to require a higher level of protection than eduGAIN
itself does. E.g., federations located in the EU like DFN AAI need to
ensure that the EU General Data Protection Regulation (GDPR) is met.

### ...

## Setup

### Preparation

The registration process requires some administrative information,
which should be collected in advance. This information is
specified in the configuration of the proxy, which uses it to
generate a metadata XML file. This file should then be used as
the source of information for the actual entity registration.
This way it is ensured that the metadata is consistent between
the proxy itself and its representation in eduGAIN.

The following information is required:

**TODO:** Describe required information

...

### Set up SP-IdP Proxy

**TODO:** Add description

The example SATOSA setup on the EOEPCA+ Development Environment
can be found
[here](https://github.com/EOEPCA/eoepca-plus/tree/deploy-develop/argocd/eoepca/iam/parts/satosa).

**To consider:**

* own DNS name required
* identifier mapping
* minimum key length of 3072 bits
* OIDC client for Keycloak
* 

...

### Register Proxy with National Federation

The proxy needs to be registered with the national federation as an SP.
Like most federations, DFN AAI provides a registration form for this
purpose.

Most of the information to provide here is contained in the metadata
file that is generated by the proxy. If there is an option to import
this file, it should be used. Otherwise the relevant information
should be extracted from the metadata file and filled into the
registration form manually.

...

### Alternative: Use Federation-Provided SP-IdP Proxy

If the selected national federation provides a preconfigured
SP-IdP proxy, it can be used instead of setting up and
registering a custom proxy.

For the DFN AAI OIDC Proxy, client credentials can be
requested from the DFN AAI help desk by e-mail. There is
no automated registration process. The following information
must be provided:

* **TODO:** Add list

The official DFN AAI OIDC Proxy is integrated with eduGAIN
and thus allows using IdPs from both DFN AAI and eduGAIN.

A test proxy is also available. It is not integrated with
eduGAIN and only allows using IdPs from the DFN AAI Test
Federation. These also include most of the production IdPs
registered with DFN AAI.

### Configure Proxy as Federated IdP in Keycloak

The SP-IdP proxy can be configured in Keycloak like any
other OIDC-based federated IdP. Refer to
[this guide](https://eoepca.readthedocs.io/projects/iam/en/latest/admin/configuration/idp/setup-other-idp/)
for details.

**TODO:** Describe specific details

The declarative example setup is contained in the
[`iam-values.yaml` file](https://github.com/EOEPCA/eoepca-plus/blob/deploy-develop/argocd/eoepca/iam/parts/values/iam-values.yaml#L200)
of the EOEPCA+ Development Environment.

...

### ...
