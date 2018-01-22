# Builds

Note that our builds are not intended to deploy new services. They will only
redeploy existing services. The build process runs on CI-servers and requires
the following environment variables to be set.

Environment variable                 | Description
--------------------                 | -----------
SSH_PRIVATE_KEY                      | A private key with access to custom repositories
COMPOSER_REPO_MAGENTO_COM_USERNAME   | The public key for Magento 2
COMPOSER_REPO_MAGENTO_COM_PASSWORD   | The private key for Magento 2
DOCKER_MACHINE_CA                    | Docker Machine CA
DOCKER_MACHINE_CLIENT_CERT           | Docker Machine client certificate
DOCKER_MACHINE_CLIENT_KEY            | Docker Machine client key

https://github.com/XIThing/generate-docker-client-certs/ explains how to
generate the DOCKER_MACHINE-certificates.
