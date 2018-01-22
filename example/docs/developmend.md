# Development

## Prerequisites

You need to be running MacOS or Linux with Docker installed.

* Docker
* composer
* [Magento 2 technology stack requirements](http://devdocs.magento.com/guides/v2.0/install-gde/system-requirements-tech.html)
* Access to repo.magento.com

## Setting up a local development environment

* `make source`. This will install the Magento 2 source and run composer install.
* `make env`. This will setup a Docker Compose environment.
* `make clean`. This will clean all data and stop any Docker Compose environments.
