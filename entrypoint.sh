#!/bin/bash

set -eo pipefail
COMMAND="$@"

# This could be used to run composer to install Magento -- this way you can install it from a Docker container that
# has all dependencies. You just pass the database credentials and you're done.
if [ -n "$COMMAND" ]; then
    echo "ENTRYPOINT: Executing override command"
    exec $COMMAND
else
    MAGENTO_CMD="bin/magento"

    # Setup Magento configuration
    chmod +x $MAGENTO_CMD

    # Check if we can connect
    while ! mysqladmin ping -h"$MYSQL_HOSTNAME" --silent; do
        echo "Waiting on database connection.."
        sleep 2
    done

    # Run composer install to get Magento up and running
    composer install

    # Set all parameters -- this apparently can fail with updates?
    $MAGENTO_CMD setup:config:set --db-host="$MYSQL_HOSTNAME" --db-name="$MYSQL_DATABASE" \
                                 --db-user="$MYSQL_USERNAME" --db-password="$MYSQL_PASSWORD" \
                                 --key="$CRYPTO_KEY"
    
    # Install Magento
    if [[ $(bin/magento setup:db:status) == *"not installed"*. ]] || [[ $(bin/magento setup:db:status) == *"none"*. ]]; then
        INSTALL_CMD="$MAGENTO_CMD setup:install --base-url="$URI" --admin-firstname="$ADMIN_FIRSTNAME" --admin-lastname="$ADMIN_LASTNAME" \
                                  --admin-email="$ADMIN_EMAIL" --admin-user="$ADMIN_USERNAME" \
                                  --admin-password="$ADMIN_PASSWORD" --language="$LANGUAGE" --currency="$CURRENCY" \
                                  --timezone="$TIMEZONE" --use-rewrites=1"

        # Set up the backend frontname -- it's recommended to not use 'backend' or 'admin' here
        if [[ -n "$BACKEND_FRONTNAME" ]]; then
            INSTALL_CMD="$INSTALL_CMD --backend-frontname=$BACKEND_FRONTNAME"
        fi

        # Run the install command
        $INSTALL_CMD
    fi

    # Set up development and production types
    if [ "$RUNTYPE" == "developer" ]; then
        echo "Switching to developer mode"
        $MAGENTO_CMD deploy:mode:set developer -s
        sed -i "s/SetEnv MAGE_MODE.*/SetEnv MAGE_MODE \"developer\"/" /etc/apache2/conf-enabled/00_magento.conf
        sed -i "s/opcache.enable=.*/opcache.enable=0" /usr/local/etc/php/conf.d/00_magento.ini
        echo 'display_errors = On' >> /usr/local/etc/php/conf.d/00_production.ini
    else
        echo "Switching to production mode"
        $MAGENTO_CMD deploy:mode:set production -s
        sed -i "s/SetEnv MAGE_MODE.*/SetEnv MAGE_MODE \"production\"/" /etc/apache2/conf-enabled/00_magento.conf
        sed -i "s/opcache.enable=.*/opcache.enable=1" /usr/local/etc/php/conf.d/00_magento.ini
        echo 'display_errors = Off' >> /usr/local/etc/php/conf.d/00_production.ini
    fi

    # Run upgrades -- we'd normally change permissions too but that's handled later
    $MAGENTO_CMD setup:upgrade && $MAGENTO_CMD setup:di:compile

    # Reset permissions -- it's probably better to do this when building the container
    echo "Changing permissions to www-data.. "
    chown -R www-data: /var/www/html

    # Start Apache
    exec /usr/local/bin/apache2-foreground
fi
