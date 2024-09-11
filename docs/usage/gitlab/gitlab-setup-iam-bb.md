# Integrating the Identity & Access Management BB as Identity Provider in GitLab

To setup a login with the IAM BB in GitLab, configuration is needed on Keycloak and GitLab side.  For the communication between Keycloak and GitLab the OpenID-Connect (OIDC) Protocol is used.

## Keycloak Configuration

Inside of keycloak, you need to configure a new client which represents the GitLab instance. For this, see the documentation on how to [Configure Keycloak Clients](../../admin/keycloak/keycloak-configuration.md#configure-a-client-).

Please enable Client Authentication, as the GitLab configuration in this documentation will require you to enter clientid + secret.\
The root url, which needs to be defined while creating the client, will be the root url of your GitLab instance `https://<GITLAB INSTANCE>/`.

## Gitlab Configuration

With the client configured in Keycloak, you need to add the details of it to the GitLab "OmniAuth" configuration.

In Linux installations, the configuration file path is `/etc/gitlab/gitlab.rb`.

### Enable the OIDC-provider

Inside the configuration file, firstly enable the OIDC-provider, please set the following setting to true:

```ruby
`gitlab_rails['omniauth_enabled'] = true`
```

</br>

GitLab blocks users by default if there is no matching user account in GitLab. To prevent this, please set: 

```ruby
`gitlab_rails['omniauth_allow_single_sign_on'] = ['openid_connect']`.
```
"openid_connect" is the internal id "name" of your OIDC-provider.
</br>
</br>

GitLab will also set new external users in a "pending approval" state. An Administrator needs to approve new users before they can access GitLab. To prevent this, please set the following setting to false: 

```ruby
`gitlab_rails['omniauth_block_auto_created_users'] = false`
```

### Configure a new OIDC-provider

To configure the new OIDC-provider please add the following configuration:

```ruby
### OmniAuth Settings
###! Docs: https://docs.gitlab.com/ee/integration/omniauth.html

gitlab_rails['omniauth_providers'] = [
  {
    name: "openid_connect", # do not change this parameter
    label: "EOEPCA+ IAM BB", # optional label for login button, defaults to "Openid Connect"
    args: {
      name: "openid_connect", # same as "name" above
      scope: ["openid", "profile", "email"],
      response_type: "code",
      issuer:  "https://<IdP DOMAIN>/realms/<REALM ID>", # the IdP Issuer URL
      client_auth_method: "query",
      discovery: true,
      uid_field: "preferred_username",
      pkce: true,
      client_options: {
        identifier: "<CLIENT ID>", # specified client_id - must match with the IdP configuration
        secret: "<CLIENT SECRET>", # specified client_secret - Must match with the IdP configuration
        redirect_uri: "http://<GITLAB INSTANCE>/users/auth/openid_connect/callback"
      }
    }
  }
```

For further information about the GitLab OIDC-Flow, visit [the Docs of GitLab](https://docs.gitlab.com/ee/administration/auth/oidc.html).