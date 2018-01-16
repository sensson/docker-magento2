# Magento2 and Docker

We recommend using Composer to manage the installation of Magento and its
dependencies. Our container comes with Composer preinstalled but we don't
run `composer install` or `composer update` in this image. Composer takes
time. It would only delay the start of a new container.

This image expects the full source, including plugins, to be added to the
folder `/var/www/html`. You will have to prepare the source code yourself
by running `composer install` on the CI-node or in your own development
environment before adding it to this folder.

Note: It does not care about how you build your source code. If Composer
is not for you feel free to use a zip file or git to manage your source.

# Building your own container

This image is intended to serve as a base for your own container to build
upon. You can create your own, private, git repository to handle all of
your sources such as composer.json itself.

A basic `Dockerfile` in your private git repository could look like:

```
FROM sensson/magento2
COPY src/cron /etc/cron.d/magento2
COPY src/ /var/www/html/
```

Keep in mind that this container has two run types. It will either start
a web server (Apache) or it will start the cron process. It never starts
both. This behaviour can be managed through the `CRON` variable. Cron
requires access to a similar source as the web application.

# Installation and updates

It can be dangerous to run automated installations or upgrades. We have
included an `UNATTENDED` environment variable. It is unset by default but
set it to `true` if you need to install or update Magento automatically.

Leave this setting unset in production. If you need to run upgrades you
could spin up a temporary container with `UNATTENDED` set to true. As it
finishes you can upgrade all running containers with the latest version
of your own image.

Disclaimer: be very careful with updates. Don't expect everything to work
and always use a temporary new branch to test your changes before merging
them back into master.

We do NOT create backups for you.

# Cronjobs

This image comes with cron support. Set `CRON` to true to have it start
cron instead of the web server. We recommend a single service in your
orchestration tool such as Kubernetes or Docker Swarm to run as cron.

# Releases

It doesn't matter what versioning scheme you use to mark your Docker images,
but it is important to pick one. 2.2.1-1 could work, where -1 would be the
release within the 2.2.1 branch, but others could work better depending on
your use case.
