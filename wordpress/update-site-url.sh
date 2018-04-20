#!/bin/bash

. /usr/local/osmosix/etc/.osmosix.sh
. /usr/local/osmosix/etc/userenv
. /usr/local/osmosix/service/utils/cfgutil.sh

mysql -u $DB_USER -p$DB_PASSWORD -e "update wordpress.wp_options set option_value = 'http://${CliqrTier_apache2_PUBLIC_IP}/WordPress-4.9-branch' where option_name = 'siteurl';"
mysql -u $DB_USER -p$DB_PASSWORD -e "update wordpress.wp_options set option_value = 'http://${CliqrTier_apache2_PUBLIC_IP}/WordPress-4.9-branch' where option_name = 'home';"
