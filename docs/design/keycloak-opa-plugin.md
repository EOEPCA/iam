# Keycloak-OPA Adapter Plugin

The Keycloak-OPA adapter plugin connects Keycloak with the Open Policy Agent (OPA).

It is an adapter that implements Keycloak's internal Policy Provider SPI.
It allows configuring authorization policies in Keycloak that delegate
policy evaluation to the Open Policy Agent (OPA).

The plugin is primarily designed and developed for use within the context of
EOEPCA, but it is not limited to this context. Thus it can be seen as a
general-purpose adapter for most cases where Keycloak shall be enabled to
delegate policy evaluation to OPA.
