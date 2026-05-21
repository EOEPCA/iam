# Change Keycloak Branding

If you don't like the default keycloak design or want to add own logos to login forms or email texts, you might want to edit the default Keycloak branding.\
This is possible by **creating your own theme** for Keycloak.

## Finding the correct branding files
You can include own branding into keycloak sites via editing the associated ``.ftl``-files inside Keycloak. To find such files, the easiest way is to look into the **keycloak project default themes**: https://github.com/keycloak/keycloak.

For example, if you want to edit the **user device flow code page**, it might be this one: https://github.com/keycloak/keycloak/blob/main/themes/src/main/resources/theme/base/login/login-oauth2-device-verify-user-code.ftl

## Applying new branding files to Keycloak
To edit ``.ftl``-files, you need to create a Keycloak Theme.\
When creating Keycloak Themes, you can import the base-Theme or keycloak.v2-Theme via ``theme.properties`` and then add your own ftl files under __the path where it should be replaced__. Keycloak will then replace the original ``.ftl``-files with the new ones.

Themes can be deployed to Keycloak via the ``theme`` directory or via an **Keycloak Extension** build as ``.jar``, placed in the ``/providers`` directory.

**The basics of creating and deploying Keycloak themes and Examples are also described in the keycloak documentation here:** https://www.keycloak.org/ui-customization/themes

A theme deployed as Keycloak extension should look like this:\
![Example Theme Deployment](example_theme_deployment.png)\
The red marked folders and files are minimum required to edit for example ``login-config-totp.ftl``.

