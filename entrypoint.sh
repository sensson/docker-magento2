#!/bin/bash
# Our entrypoint manages both new as existing Magento2 installations.
#
# Apache License 2.0
# Copyright (c) 2017 Sensson and contributors
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -eo pipefail
COMMAND="$@"

# Override the default command
if [ -n "${COMMAND}" ]; then
  echo "ENTRYPOINT: Executing override command"
  exec $COMMAND
else
  # Check if we can connect to the database
  while ! mysqladmin ping -h"${MYSQL_HOSTNAME}" --silent; do
    echo "Waiting on database connection.."
    sleep 2
  done

  # Measure the time it takes to bootstrap the container
  START=`date +%s`

  # Set the base Magento command to bin/magento
  CMD_MAGENTO="bin/magento" && chmod +x $CMD_MAGENTO

  # Set the config command
  CMD_CONFIG="${CMD_MAGENTO} setup:config:set --db-host="${MYSQL_HOSTNAME}" \
              --db-name="${MYSQL_DATABASE}" --db-user="${MYSQL_USERNAME}" \
              --db-password="${MYSQL_PASSWORD}" --key="${CRYPTO_KEY}""

  # Set up the backend frontname -- it's recommended to not use 'backend' or
  # 'admin' here
  if [[ -n "${BACKEND_FRONTNAME}" ]]; then
    CMD_CONFIG="${CMD_CONFIG} --backend-frontname=${BACKEND_FRONTNAME}"
  fi

  # Set the install command
  CMD_INSTALL="${CMD_MAGENTO} setup:install --base-url="${URI}" \
                --admin-firstname="${ADMIN_FIRSTNAME}" \
                --admin-lastname="${ADMIN_LASTNAME}" \
                --admin-email="${ADMIN_EMAIL}" \
                --admin-user="${ADMIN_USERNAME}" \
                --admin-password="${ADMIN_PASSWORD}" --language="${LANGUAGE}" \
                --currency="${CURRENCY}" --timezone="${TIMEZONE}" \
                --use-rewrites=1"

  # Run configuration command
  $CMD_CONFIG

  # Run setup:db:status to get an idea about the current state
  CHECK_STATUS=$($CMD_MAGENTO setup:db:status 2>&1 || true)

  # Automated installs and updates can be tricky if they are not handled
  # properly. This could for example run updates twice if you're updating
  # a deployment in Kubernetes or service in Docker Swarm. There are very
  # sane reasons NOT to run automated installations or updates.
  if [ "${UNATTENDED}" == "true" ]; then
    if [[ $CHECK_STATUS == *"up to date"*. ]]; then
      echo "Installation is up to date"
    else
      CHECK_PLUGINS=$((echo $CHECK_STATUS | grep -o '\<none\>' || true) | \
                      wc -l)

      if [[ "${CHECK_PLUGINS}" -eq "0" ]]; then
        UNINSTALLED_PLUGINS=0
        echo "Update required."
      else
        UNINSTALLED_PLUGINS=$(expr $CHECK_PLUGINS / 2)
        echo "Found ${UNINSTALLED_PLUGINS} uninstalled plugin(s)."
      fi

      # This is an arbitrary number. As we're checking on 'none' as an
      # individual word this should be able to handle minor upgrades of
      # Magento (2.1 > 2.2)
      if [[ $UNINSTALLED_PLUGINS -gt 20 ]]; then
        echo "Running installer.."
        $CMD_INSTALL
      else
        echo "Running upgrade.."
        $CMD_MAGENTO setup:upgrade
      fi
    fi
  fi

  # Run code compilation
  $CMD_MAGENTO setup:di:compile

  # Empty line
  echo

  # Check RUNTYPE and decide if we run in production or development
  if [ "$RUNTYPE" == "development" ]; then
    #  DEVELOPMENT
    echo "Switching to development mode"
    $CMD_MAGENTO deploy:mode:set developer -s

    # Change config files
    sed -i "s/SetEnv MAGE_MODE.*/SetEnv MAGE_MODE \"developer\"/" \
      /etc/apache2/conf-enabled/00_magento.conf
    sed -i "s/opcache.enable=.*/opcache.enable=0/" \
      /usr/local/etc/php/conf.d/00_magento.ini

    # Enable error reporting
    echo 'display_errors = On' >> /usr/local/etc/php/conf.d/00_production.ini
  else
    # PRODUCTION
    echo "Switching to production mode"
    $CMD_MAGENTO deploy:mode:set production -s

    # Change config files
    sed -i "s/SetEnv MAGE_MODE.*/SetEnv MAGE_MODE \"production\"/" \
      /etc/apache2/conf-enabled/00_magento.conf
    sed -i "s/opcache.enable=.*/opcache.enable=1/" \
      /usr/local/etc/php/conf.d/00_magento.ini

    # Disable error reporting
    echo 'display_errors = Off' >> /usr/local/etc/php/conf.d/00_production.ini

    # Deploy static content
    $CMD_MAGENTO setup:static-content:deploy
  fi

  echo "Changing permissions to www-data.. "
  chown -R www-data: /var/www/html

  # Calculate the number of seconds required to bootstrap the container
  END=`date +%s`
  RUNTIME=$((END-START))
  echo "Startup preparation finished in ${RUNTIME} seconds"

  # Run any post install hooks (e.g. run a database script). You can't interact
  # with the Magento API at this point as you need a running webserver.
  POST_INSTALL_HOOK="/hooks/post_install.sh"
  if [ -f "${POST_INSTALL_HOOK}" ]; then
    echo "HOOKS: Running POST_INSTALL_HOOK"
    chmod +x "${POST_INSTALL_HOOK}"
    $POST_INSTALL_HOOK
  fi

  # If CRON is set to true we only start cron in this container. We needed to
  # go through the same process as Apache to match all requirements.
  if [ "${CRON}" == "true" ]; then
    echo "CRON: Starting crontab"

    # Make sure all files have the correct permissions and start cron
    find /etc/cron* -type f -exec chmod 0644 {} \;
    exec cron -f
  else
    echo "APACHE: Starting webserver"
    exec /usr/local/bin/apache2-foreground
  fi
fi
