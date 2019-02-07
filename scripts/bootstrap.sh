#!/usr/bin/env bash

## Source of the vercomp function: https://stackoverflow.com/questions/4023830/how-to-compare-two-strings-in-dot-separated-version-format-in-bash
##vercomp () {
##    if [[ $1 == $2 ]]
##    then
##        return 0
##    fi
##    local IFS=.
##    local i ver1=($1) ver2=($2)
##    # fill empty fields in ver1 with zeros
##    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++))
##    do
##        ver1[i]=0
##    done
##    for ((i=0; i<${#ver1[@]}; i++))
##    do
##        if [[ -z ${ver2[i]} ]]
##        then
##            # fill empty fields in ver2 with zeros
##            ver2[i]=0
##        fi
##        if ((10#${ver1[i]} > 10#${ver2[i]}))
##        then
##            return 1
##        fi
##        if ((10#${ver1[i]} < 10#${ver2[i]}))
##        then
##            return 2
##        fi
##    done
##    return 0
##}

MISP_BRANCH='2.4'

# Grub config (reverts network interface names to ethX)
GRUB_CMDLINE_LINUX="net.ifnames=0 biosdevname=0"
DEFAULT_GRUB=/etc/default/grub

# Ubuntu version
UBUNTU_VERSION="$(lsb_release -r -s)"

# MISP Configurables
PATH_TO_MISP='/var/www/MISP'
CAKE="${PATH_TO_MISP}/app/Console/cake"
MISP_BASEURL=''
MISP_LIVE='1'

# Database configuration
DBHOST='localhost'
DBNAME='misp'
DBUSER_ADMIN='root'
DBPASSWORD_ADMIN="$(openssl rand -hex 32)"
DBUSER_MISP='misp'
DBPASSWORD_MISP="$(openssl rand -hex 32)"

# Webserver configuration
FQDN='localhost'

# Timing creation
TIME_START=$(date +%s)

# OpenSSL configuration
OPENSSL_C='LU'
OPENSSL_ST='State'
OPENSSL_L='Location'
OPENSSL_O='Organization'
OPENSSL_OU='Organizational Unit'
OPENSSL_CN='Common Name'
OPENSSL_EMAILADDRESS='info@localhost'

# GPG configuration
GPG_REAL_NAME='Autogenerated Key'
GPG_COMMENT='WARNING: MISP AutoGenerated VM consider this Key VOID!'
GPG_EMAIL_ADDRESS='admin@admin.test'
GPG_KEY_LENGTH='2048'
GPG_PASSPHRASE='Password1234'

# php.ini configuration
upload_max_filesize=50M
post_max_size=50M
max_execution_time=300
memory_limit=512M
PHP_INI='/etc/php/7.2/apache2/php.ini'
## Starting Ubuntu 18.04 php72 is default
##vercomp 18.04 ${UBUNTU_VERSION}
##case $? in
##    0) op='=';PHP_INI='/etc/php/7.2/apache2/php.ini';;
##    1) op='>';PHP_INI='/etc/php/7.2/apache2/php.ini';;
##    2) op='<';PHP_INI='/etc/php/7.0/apache2/php.ini';;
##esac


echo "--- Installing MISP… ---"

echo "--- Updating packages list ---"
sudo apt-get -qq update > /dev/null 2>&1

echo "--- Upgrading and autoremoving packages ---"
sudo apt-get -y upgrade > /dev/null 2>&1
sudo apt-get -y autoremove > /dev/null 2>&1

echo "--- Install base packages ---"
sudo apt-get -y install curl net-tools gcc git gnupg-agent make python openssl redis-server sudo tmux vim virtualenvwrapper virtualenv zip python3-pythonmagick tesseract-ocr htop imagemagick asciidoctor jq ntp ntpdate > /dev/null 2>&1
## Remove mailutils, it probably makes the script stuck on a user prompt....

echo "--- Installing and configuring Postfix ---"
# # Postfix Configuration: Satellite system
# # change the relay server later with:
# sudo postconf -e 'relayhost = example.com'
# sudo postfix reload
echo "postfix postfix/mailname string `hostname`.misp.local" | debconf-set-selections
echo "postfix postfix/main_mailer_type string 'Satellite system'" | debconf-set-selections
sudo apt-get install -y postfix > /dev/null 2>&1

echo "--- Installing MariaDB specific packages and settings ---"
sudo apt-get install -y mariadb-client mariadb-server > /dev/null 2>&1
# Secure the MariaDB installation (especially by setting a strong root password)
sleep 10 # give some time to the DB to launch...
sudo systemctl restart mariadb.service
sleep 10
sudo apt-get install -y expect > /dev/null 2>&1
## do we need to spawn mysql_secure_install with sudo in future?
# If yes, see here: https://stackoverflow.com/a/52961331/610224
expect -f - <<-EOF
  set timeout 10
  spawn mysql_secure_installation
  expect "Enter current password for root (enter for none):"
  send -- "\r"
  expect "Set root password?"
  send -- "y\r"
  expect "New password:"
  send -- "${DBPASSWORD_ADMIN}\r"
  expect "Re-enter new password:"
  send -- "${DBPASSWORD_ADMIN}\r"
  expect "Remove anonymous users?"
  send -- "y\r"
  expect "Disallow root login remotely?"
  send -- "y\r"
  expect "Remove test database and access to it?"
  send -- "y\r"
  expect "Reload privilege tables now?"
  send -- "y\r"
  expect eof
EOF
sudo apt-get purge -y expect > /dev/null 2>&1


echo "--- Installing Apache2 ---"
sudo apt-get install -y apache2 apache2-doc apache2-utils > /dev/null 2>&1
echo "--- Installing mod-wsgi-py3 for misp-dashboard ---"
sudo apt-get install -y libapache2-mod-wsgi-py3 > /dev/null 2>&1
sudo a2dismod status > /dev/null 2>&1
sudo a2enmod ssl > /dev/null 2>&1
sudo a2enmod rewrite > /dev/null 2>&1
sudo a2enmod headers > /dev/null 2>&1
sudo a2dissite 000-default > /dev/null 2>&1
sudo a2ensite default-ssl > /dev/null 2>&1


echo "--- Installing PHP-specific packages ---"
sudo apt-get install -y libapache2-mod-php php php-cli php-dev php-mbstring php-json php-mysql php-opcache php-readline php-redis php-xml > /dev/null 2>&1

echo "--- Configuring PHP ---"
for key in upload_max_filesize post_max_size max_execution_time max_input_time memory_limit
do
 sudo sed -i "s/^\($key\).*/\1 = $(eval echo \${$key})/" $PHP_INI
done

echo "--- Restarting Apache ---"
sudo systemctl restart apache2 > /dev/null 2>&1


echo "--- Retrieving MISP ---"
## Double check perms.
sudo mkdir $PATH_TO_MISP
sudo chown www-data:www-data $PATH_TO_MISP
cd $PATH_TO_MISP
sudo -u www-data git clone -b $MISP_BRANCH https://github.com/MISP/MISP.git $PATH_TO_MISP > /dev/null 2>&1
#git checkout tags/$(git describe --tags `git rev-list --tags --max-count=1`)
sudo -u www-data git config core.filemode false
# chown -R www-data $PATH_TO_MISP
# chgrp -R www-data $PATH_TO_MISP
# chmod -R 700 $PATH_TO_MISP

echo "--- Creating a python3 virtualenv in /var/www/MISP/venv ---"
sudo -u www-data virtualenv -p python3 /var/www/MISP/venv

# make pip happy
sudo mkdir /var/www/.cache/
sudo chown www-data:www-data /var/www/.cache

echo "--- Installing Mitre's STIX ---"
sudo apt-get install -y python-dev python3-dev python3-pip libxml2-dev libxslt1-dev zlib1g-dev python-setuptools > /dev/null 2>&1
cd $PATH_TO_MISP/app/files/scripts
sudo -u www-data git clone https://github.com/CybOXProject/python-cybox.git > /dev/null 2>&1
sudo -u www-data git clone https://github.com/STIXProject/python-stix.git > /dev/null 2>&1
cd $PATH_TO_MISP/app/files/scripts/python-cybox
sudo -H -u www-data ${PATH_TO_MISP}/venv/bin/pip install . > /dev/null 2>&1
cd $PATH_TO_MISP/app/files/scripts/python-stix
sudo -H -u www-data ${PATH_TO_MISP}/venv/bin/pip install . > /dev/null 2>&1
# install mixbox to accomodate the new STIX dependencies:
cd $PATH_TO_MISP/app/files/scripts/
sudo -u www-data git clone https://github.com/CybOXProject/mixbox.git > /dev/null 2>&1
cd $PATH_TO_MISP/app/files/scripts/mixbox
sudo -H -u www-data ${PATH_TO_MISP}/venv/bin/pip install . > /dev/null 2>&1

echo "--- Installing misp-dashboard ---"
cd /var/www
sudo mkdir misp-dashboard
sudo chown www-data:www-data misp-dashboard
sudo -u www-data git clone https://github.com/MISP/misp-dashboard.git > /dev/null 2>&1
cd misp-dashboard
sudo /var/www/misp-dashboard/install_dependencies.sh > /dev/null 2>&1
sudo sed -i "s/^host\ =\ localhost/host\ =\ 0.0.0.0/g" /var/www/misp-dashboard/config/config.cfg

echo "--- Retrieving CakePHP… ---"
# CakePHP is included as a submodule of MISP, execute the following commands to let git fetch it:
cd $PATH_TO_MISP
sudo -u www-data git submodule init > /dev/null 2>&1
sudo -u www-data git submodule update > /dev/null 2>&1
# Once done, install CakeResque along with its dependencies if you intend to use the built in background jobs:
# Make composer cache happy
mkdir /var/www/.composer ; chown www-data:www-data /var/www/.composer
cd $PATH_TO_MISP/app
sudo -u www-data php composer.phar require kamisama/cake-resque:4.1.2 > /dev/null 2>&1
sudo -u www-data php composer.phar config vendor-dir Vendor > /dev/null 2>&1
sudo -u www-data php composer.phar install > /dev/null 2>&1
# Enable CakeResque with php-redis
sudo phpenmod redis
# To use the scheduler worker for scheduled tasks, do the following:
sudo -u www-data cp -fa $PATH_TO_MISP/INSTALL/setup/config.php $PATH_TO_MISP/app/Plugin/CakeResque/Config/config.php


echo "--- Setting the permissions… ---"
sudo chown -R www-data:www-data $PATH_TO_MISP
sudo chmod -R 750 $PATH_TO_MISP
sudo chmod -R g+ws $PATH_TO_MISP/app/tmp
sudo chmod -R g+ws $PATH_TO_MISP/app/files
sudo chmod -R g+ws $PATH_TO_MISP/app/files/scripts/tmp


echo "--- Creating a database user… ---"
sudo mysql -u $DBUSER_ADMIN -p$DBPASSWORD_ADMIN -e "create database $DBNAME;"
sudo mysql -u $DBUSER_ADMIN -p$DBPASSWORD_ADMIN -e "grant usage on *.* to $DBNAME@localhost identified by '$DBPASSWORD_MISP';"
sudo mysql -u $DBUSER_ADMIN -p$DBPASSWORD_ADMIN -e "grant all privileges on $DBNAME.* to '$DBUSER_MISP'@'localhost';"
sudo mysql -u $DBUSER_ADMIN -p$DBPASSWORD_ADMIN -e "flush privileges;"
# Import the empty MISP database from MYSQL.sql
sudo -u www-data cat /var/www/MISP/INSTALL/MYSQL.sql | mysql -u $DBUSER_MISP -p$DBPASSWORD_MISP $DBNAME


echo "--- Configuring Apache… ---"
# !!! apache.24.misp.ssl seems to be missing
#cp $PATH_TO_MISP/INSTALL/apache.24.misp.ssl /etc/apache2/sites-available/misp-ssl.conf
# If a valid SSL certificate is not already created for the server, create a self-signed certificate:
sudo openssl req -newkey rsa:4096 -days 365 -nodes -x509 -subj "/C=$OPENSSL_C/ST=$OPENSSL_ST/L=$OPENSSL_L/O=<$OPENSSL_O/OU=$OPENSSL_OU/CN=$OPENSSL_CN/emailAddress=$OPENSSL_EMAILADDRESS" -keyout /etc/ssl/private/misp.local.key -out /etc/ssl/private/misp.local.crt > /dev/null 2>&1


echo "--- Adding Listen 8001 for misp-dashboard ---"
sudo sed -i '/Listen 80/a Listen 0.0.0.0:8001' /etc/apache2/ports.conf

echo "--- Add a VirtualHost for MISP and misp-dashboard ---"
## Again double check this perm madness ;)
sudo cat > /etc/apache2/sites-available/misp-ssl.conf <<EOF
<VirtualHost *:80>
    ServerAdmin admin@misp.local
    ServerName misp.local
    DocumentRoot $PATH_TO_MISP/app/webroot

    <Directory $PATH_TO_MISP/app/webroot>
        Options -Indexes
        AllowOverride all
        Require all granted
    </Directory>

    LogLevel warn
    ErrorLog /var/log/apache2/misp.local_error.log
    CustomLog /var/log/apache2/misp.local_access.log combined
    ServerSignature Off
    Header set X-Content-Type-Options nosniff
    Header set X-Frame-Options DENY
</VirtualHost>
EOF

sudo cat > /etc/apache2/sites-available/misp-dashboard.conf <<EOF
<VirtualHost *:8001>
    ServerAdmin admin@misp.local
    ServerName misp.local

    DocumentRoot /var/www/misp-dashboard

    WSGIDaemonProcess misp-dashboard \
       user=misp group=misp \
       python-home=/var/www/misp-dashboard/DASHENV \
       processes=1 \
       threads=15 \
       maximum-requests=5000 \
       listen-backlog=100 \
       queue-timeout=45 \
       socket-timeout=60 \
       connect-timeout=15 \
       request-timeout=60 \
       inactivity-timeout=0 \
       deadlock-timeout=60 \
       graceful-timeout=15 \
       eviction-timeout=0 \
       shutdown-timeout=5 \
       send-buffer-size=0 \
       receive-buffer-size=0 \
       header-buffer-size=0 \
       response-buffer-size=0 \
       server-metrics=Off

    WSGIScriptAlias / /var/www/misp-dashboard/misp-dashboard.wsgi

    <Directory /var/www/misp-dashboard>
        WSGIProcessGroup misp-dashboard
        WSGIApplicationGroup %{GLOBAL}
        Require all granted
    </Directory>

    LogLevel info
    ErrorLog /var/log/apache2/misp-dashboard.local_error.log
    CustomLog /var/log/apache2/misp-dashboard.local_access.log combined
    ServerSignature Off
</VirtualHost>
EOF

# cat > /etc/apache2/sites-available/misp-ssl.conf <<EOF
# <VirtualHost *:80>
#         ServerName misp.local
#
#         Redirect permanent / https://$FQDN
#
#         LogLevel warn
#         ErrorLog /var/log/apache2/misp.local_error.log
#         CustomLog /var/log/apache2/misp.local_access.log combined
#         ServerSignature Off
# </VirtualHost>
#
# <VirtualHost *:443>
#         ServerAdmin me@me.local
#         ServerName misp.local
#         DocumentRoot $PATH_TO_MISP/app/webroot
#
#         <Directory $PATH_TO_MISP/app/webroot>
#             Options -Indexes
#             AllowOverride all
#             Require all granted
#         </Directory>
#
#         SSLEngine On
#         SSLCertificateFile /etc/ssl/private/misp.local.crt
#         SSLCertificateKeyFile /etc/ssl/private/misp.local.key
#         #SSLCertificateChainFile /etc/ssl/private/misp-chain.crt
#
#         LogLevel warn
#         ErrorLog /var/log/apache2/misp.local_error.log
#         CustomLog /var/log/apache2/misp.local_access.log combined
#         ServerSignature Off
# </VirtualHost>
# EOF
# activate new vhost
sudo a2dissite default-ssl > /dev/null 2>&1
sudo a2ensite misp-ssl > /dev/null 2>&1
sudo a2ensite misp-dashboard > /dev/null 2>&1


echo "--- Restarting Apache ---"
sudo systemctl restart apache2 > /dev/null 2>&1


echo "--- Configuring log rotation ---"
sudo cp $PATH_TO_MISP/INSTALL/misp.logrotate /etc/logrotate.d/misp


echo "--- MISP configuration ---"
# There are 4 sample configuration files in /var/www/MISP/app/Config that need to be copied
sudo -u www-data cp -a $PATH_TO_MISP/app/Config/bootstrap.default.php /var/www/MISP/app/Config/bootstrap.php
sudo -u www-data cp -a $PATH_TO_MISP/app/Config/database.default.php /var/www/MISP/app/Config/database.php
sudo -u www-data cp -a $PATH_TO_MISP/app/Config/core.default.php /var/www/MISP/app/Config/core.php
sudo -u www-data cp -a $PATH_TO_MISP/app/Config/config.default.php /var/www/MISP/app/Config/config.php
sudo -u www-data cat > $PATH_TO_MISP/app/Config/database.php <<EOF
<?php
class DATABASE_CONFIG {
        public \$default = array(
                'datasource' => 'Database/Mysql',
                //'datasource' => 'Database/Postgres',
                'persistent' => false,
                'host' => '$DBHOST',
                'login' => '$DBUSER_MISP',
                'port' => 3306, // MySQL & MariaDB
                //'port' => 5432, // PostgreSQL
                'password' => '$DBPASSWORD_MISP',
                'database' => '$DBNAME',
                'prefix' => '',
                'encoding' => 'utf8',
        );
}
EOF
# and make sure the file permissions are still OK
sudo chown -R www-data:www-data $PATH_TO_MISP/app/Config
sudo chmod -R 750 $PATH_TO_MISP/app/Config
# Set some MISP directives with the command line tool
$CAKE Live $MISP_LIVE > /dev/null

# Enable ZeroMQ
$CAKE Admin setSetting "Plugin.ZeroMQ_enable" true > /dev/null
$CAKE Admin setSetting "Plugin.ZeroMQ_event_notifications_enable" true > /dev/null
$CAKE Admin setSetting "Plugin.ZeroMQ_object_notifications_enable" true > /dev/null
$CAKE Admin setSetting "Plugin.ZeroMQ_object_reference_notifications_enable" true > /dev/null
$CAKE Admin setSetting "Plugin.ZeroMQ_attribute_notifications_enable" true > /dev/null
$CAKE Admin setSetting "Plugin.ZeroMQ_sighting_notifications_enable" true > /dev/null
$CAKE Admin setSetting "Plugin.ZeroMQ_user_notifications_enable" true > /dev/null
$CAKE Admin setSetting "Plugin.ZeroMQ_organisation_notifications_enable" true > /dev/null
$CAKE Admin setSetting "Plugin.ZeroMQ_port" 50000 > /dev/null
$CAKE Admin setSetting "Plugin.ZeroMQ_redis_host" "localhost" > /dev/null
$CAKE Admin setSetting "Plugin.ZeroMQ_redis_port" 6379 > /dev/null
$CAKE Admin setSetting "Plugin.ZeroMQ_redis_database" 1 > /dev/null
$CAKE Admin setSetting "Plugin.ZeroMQ_redis_namespace" "mispq" > /dev/null
$CAKE Admin setSetting "Plugin.ZeroMQ_include_attachments" false > /dev/null
$CAKE Admin setSetting "Plugin.ZeroMQ_tag_notifications_enable" false > /dev/null
$CAKE Admin setSetting "Plugin.ZeroMQ_audit_notifications_enable" false > /dev/null

# Enable GnuPG
$CAKE Admin setSetting "GnuPG.email" "admin@admin.test" > /dev/null
$CAKE Admin setSetting "GnuPG.homedir" ${PATH_TO_MISP}/.gnupg > /dev/null
$CAKE Admin setSetting "GnuPG.binary" `which gpg` > /dev/null
$CAKE Admin setSetting "GnuPG.password" "Password1234" > /dev/null

# Enable Enrichment set better timeouts
$CAKE Admin setSetting "Plugin.Enrichment_services_enable" true > /dev/null
$CAKE Admin setSetting "Plugin.Enrichment_hover_enable" true > /dev/null
$CAKE Admin setSetting "Plugin.Enrichment_timeout" 300 > /dev/null
$CAKE Admin setSetting "Plugin.Enrichment_hover_timeout" 150 > /dev/null
$CAKE Admin setSetting "Plugin.Enrichment_cve_enabled" true > /dev/null
$CAKE Admin setSetting "Plugin.Enrichment_dns_enabled" true > /dev/null
$CAKE Admin setSetting "Plugin.Enrichment_services_url" "http://127.0.0.1" > /dev/null
$CAKE Admin setSetting "Plugin.Enrichment_services_port" 6666 > /dev/null
$CAKE Admin setSetting "Plugin.Enrichment_vmray_submit_enabled" false > /dev/null
$CAKE Admin setSetting "Plugin.Enrichment_asn_history_enabled" false > /dev/null
$CAKE Admin setSetting "Plugin.Enrichment_circl_passivedns_enabled" false > /dev/null
$CAKE Admin setSetting "Plugin.Enrichment_circl_passivessl_enabled" false > /dev/null
$CAKE Admin setSetting "Plugin.Enrichment_countrycode_enabled" false > /dev/null
$CAKE Admin setSetting "Plugin.Enrichment_domaintools_enabled" false > /dev/null
$CAKE Admin setSetting "Plugin.Enrichment_eupi_enabled" false > /dev/null
$CAKE Admin setSetting "Plugin.Enrichment_farsight_passivedns_enabled" false > /dev/null
$CAKE Admin setSetting "Plugin.Enrichment_ipasn_enabled" false > /dev/null
$CAKE Admin setSetting "Plugin.Enrichment_passivetotal_enabled" false > /dev/null
$CAKE Admin setSetting "Plugin.Enrichment_sourcecache_enabled" false > /dev/null
$CAKE Admin setSetting "Plugin.Enrichment_virustotal_enabled" false > /dev/null
$CAKE Admin setSetting "Plugin.Enrichment_whois_enabled" false > /dev/null
$CAKE Admin setSetting "Plugin.Enrichment_shodan_enabled" false > /dev/null
$CAKE Admin setSetting "Plugin.Enrichment_reversedns_enabled" false > /dev/null
$CAKE Admin setSetting "Plugin.Enrichment_geoip_country_enabled" false > /dev/null
$CAKE Admin setSetting "Plugin.Enrichment_wiki_enabled" false > /dev/null
$CAKE Admin setSetting "Plugin.Enrichment_iprep_enabled" false > /dev/null
$CAKE Admin setSetting "Plugin.Enrichment_threatminer_enabled" false > /dev/null
$CAKE Admin setSetting "Plugin.Enrichment_otx_enabled" false > /dev/null
$CAKE Admin setSetting "Plugin.Enrichment_threatcrowd_enabled" false > /dev/null
$CAKE Admin setSetting "Plugin.Enrichment_vulndb_enabled" false > /dev/null
$CAKE Admin setSetting "Plugin.Enrichment_crowdstrike_falcon_enabled" false > /dev/null
$CAKE Admin setSetting "Plugin.Enrichment_yara_syntax_validator_enabled" false > /dev/null
$CAKE Admin setSetting "Plugin.Enrichment_hashdd_enabled" false > /dev/null
$CAKE Admin setSetting "Plugin.Enrichment_onyphe_enabled" false > /dev/null
$CAKE Admin setSetting "Plugin.Enrichment_onyphe_full_enabled" false > /dev/null
$CAKE Admin setSetting "Plugin.Enrichment_rbl_enabled" false > /dev/null
$CAKE Admin setSetting "Plugin.Enrichment_xforceexchange_enabled" false > /dev/null
$CAKE Admin setSetting "Plugin.Enrichment_xforceexchange_enabled" false > /dev/null

# Enable Import modules set better timout
$CAKE Admin setSetting "Plugin.Import_services_enable" true > /dev/null
$CAKE Admin setSetting "Plugin.Import_services_url" "http://127.0.0.1" > /dev/null
$CAKE Admin setSetting "Plugin.Import_services_port" 6666 > /dev/null
$CAKE Admin setSetting "Plugin.Import_timeout" 300 > /dev/null
$CAKE Admin setSetting "Plugin.Import_ocr_enabled" true > /dev/null
$CAKE Admin setSetting "Plugin.Import_csvimport_enabled" true > /dev/null
$CAKE Admin setSetting "Plugin.Import_vmray_import_enabled" false > /dev/null
$CAKE Admin setSetting "Plugin.Import_testimport_enabled" false > /dev/null
$CAKE Admin setSetting "Plugin.Import_ocr_enabled" false > /dev/null
$CAKE Admin setSetting "Plugin.Import_cuckooimport_enabled" false > /dev/null
$CAKE Admin setSetting "Plugin.Import_goamlimport_enabled" false > /dev/null
$CAKE Admin setSetting "Plugin.Import_email_import_enabled" false > /dev/null
$CAKE Admin setSetting "Plugin.Import_mispjson_enabled" false > /dev/null
$CAKE Admin setSetting "Plugin.Import_openiocimport_enabled" false > /dev/null
$CAKE Admin setSetting "Plugin.Import_threatanalyzer_import_enabled" false > /dev/null

# Enable Export modules set better timout
$CAKE Admin setSetting "Plugin.Export_services_enable" true > /dev/null
$CAKE Admin setSetting "Plugin.Export_services_url" "http://127.0.0.1" > /dev/null
$CAKE Admin setSetting "Plugin.Export_services_port" 6666 > /dev/null
$CAKE Admin setSetting "Plugin.Export_timeout" 300 > /dev/null
$CAKE Admin setSetting "Plugin.Export_pdfexport_enabled" true > /dev/null
$CAKE Admin setSetting "Plugin.Export_testexport_enabled" false > /dev/null
$CAKE Admin setSetting "Plugin.Export_testexport_restrict" 1 > /dev/null
$CAKE Admin setSetting "Plugin.Export_cef_export_enabled" false > /dev/null
$CAKE Admin setSetting "Plugin.Export_liteexport_enabled" false > /dev/null
$CAKE Admin setSetting "Plugin.Export_goamlexport_enabled" false > /dev/null
$CAKE Admin setSetting "Plugin.Export_threat_connect_export_enabled" false > /dev/null
$CAKE Admin setSetting "Plugin.Export_threatStream_misp_export_enabled" false > /dev/null


# Enable installer org and tune some configurables
$CAKE Admin setSetting "MISP.host_org_id" 1 > /dev/null
$CAKE Admin setSetting "MISP.email" "info@admin.test" > /dev/null
$CAKE Admin setSetting "MISP.disable_emailing" true > /dev/null
$CAKE Admin setSetting "MISP.contact" "info@admin.test" > /dev/null
$CAKE Admin setSetting "MISP.disablerestalert" true > /dev/null
$CAKE Admin setSetting "MISP.showCorrelationsOnIndex" true > /dev/null

# Provisional Cortex tunes
$CAKE Admin setSetting "Plugin.Cortex_services_enable" false > /dev/null
$CAKE Admin setSetting "Plugin.Cortex_services_url" "http://127.0.0.1" > /dev/null
$CAKE Admin setSetting "Plugin.Cortex_services_port" 9000 > /dev/null
$CAKE Admin setSetting "Plugin.Cortex_timeout" 120 > /dev/null
$CAKE Admin setSetting "Plugin.Cortex_services_url" "http://127.0.0.1" > /dev/null
$CAKE Admin setSetting "Plugin.Cortex_services_port" 9000 > /dev/null
$CAKE Admin setSetting "Plugin.Cortex_services_timeout" 120 > /dev/null
$CAKE Admin setSetting "Plugin.Cortex_services_authkey" "" > /dev/null
$CAKE Admin setSetting "Plugin.Cortex_ssl_verify_peer" false > /dev/null
$CAKE Admin setSetting "Plugin.Cortex_ssl_verify_host" false > /dev/null
$CAKE Admin setSetting "Plugin.Cortex_ssl_allow_self_signed" true > /dev/null

# Provisional Elastic Search tunes
$CAKE Admin setSetting "Plugin.ElasticSearch_logging_enable" false > /dev/null

# Various plugin sightings settings
$CAKE Admin setSetting "Plugin.Sightings_policy" 0 > /dev/null
$CAKE Admin setSetting "Plugin.Sightings_anonymise" false > /dev/null
$CAKE Admin setSetting "Plugin.Sightings_range" 365 > /dev/null

# Plugin CustomAuth tuneable
$CAKE Admin setSetting "Plugin.CustomAuth_disable_logout" false > /dev/null

# RPZ Plugin settings

$CAKE Admin setSetting "Plugin.RPZ_policy" "DROP" > /dev/null
$CAKE Admin setSetting "Plugin.RPZ_walled_garden" "127.0.0.1" > /dev/null
$CAKE Admin setSetting "Plugin.RPZ_serial" "\$date00" > /dev/null
$CAKE Admin setSetting "Plugin.RPZ_refresh" "2h" > /dev/null
$CAKE Admin setSetting "Plugin.RPZ_retry" "30m" > /dev/null
$CAKE Admin setSetting "Plugin.RPZ_expiry" "30d" > /dev/null
$CAKE Admin setSetting "Plugin.RPZ_minimum_ttl" "1h" > /dev/null
$CAKE Admin setSetting "Plugin.RPZ_ttl" "1w" > /dev/null
$CAKE Admin setSetting "Plugin.RPZ_ns" "localhost." > /dev/null
$CAKE Admin setSetting "Plugin.RPZ_ns_alt" "" > /dev/null
$CAKE Admin setSetting "Plugin.RPZ_email" "root.localhost" > /dev/null

# Force defaults to make MISP Server Settings less RED
$CAKE Admin setSetting "MISP.language" "eng" > /dev/null
$CAKE Admin setSetting "MISP.proposals_block_attributes" false > /dev/null
## Redis block
$CAKE Admin setSetting "MISP.redis_host" "127.0.0.1" > /dev/null
$CAKE Admin setSetting "MISP.redis_port" 6379 > /dev/null
$CAKE Admin setSetting "MISP.redis_database" 13 > /dev/null
$CAKE Admin setSetting "MISP.redis_password" "" > /dev/null

# Force defaults to make MISP Server Settings less YELLOW
$CAKE Admin setSetting "MISP.ssdeep_correlation_threshold" 40 > /dev/null
$CAKE Admin setSetting "MISP.extended_alert_subject" false > /dev/null
$CAKE Admin setSetting "MISP.default_event_threat_level" 4 > /dev/null
$CAKE Admin setSetting "MISP.newUserText" "Dear new MISP user,\\n\\nWe would hereby like to welcome you to the \$org MISP community.\\n\\n Use the credentials below to log into MISP at \$misp, where you will be prompted to manually change your password to something of your own choice.\\n\\nUsername: \$username\\nPassword: \$password\\n\\nIf you have any questions, don't hesitate to contact us at: \$contact.\\n\\nBest regards,\\nYour \$org MISP support team" > /dev/null
$CAKE Admin setSetting "MISP.passwordResetText" "Dear MISP user,\\n\\nA password reset has been triggered for your account. Use the below provided temporary password to log into MISP at \$misp, where you will be prompted to manually change your password to something of your own choice.\\n\\nUsername: \$username\\nYour temporary password: \$password\\n\\nIf you have any questions, don't hesitate to contact us at: \$contact.\\n\\nBest regards,\\nYour \$org MISP support team" > /dev/null
$CAKE Admin setSetting "MISP.enableEventBlacklisting" true > /dev/null
$CAKE Admin setSetting "MISP.enableOrgBlacklisting" true > /dev/null
$CAKE Admin setSetting "MISP.log_client_ip" false > /dev/null
$CAKE Admin setSetting "MISP.log_auth" false > /dev/null
$CAKE Admin setSetting "MISP.disableUserSelfManagement" false > /dev/null
$CAKE Admin setSetting "MISP.block_event_alert" false > /dev/null
$CAKE Admin setSetting "MISP.block_event_alert_tag" "no-alerts=\"true\"" > /dev/null
$CAKE Admin setSetting "MISP.block_old_event_alert" false > /dev/null
$CAKE Admin setSetting "MISP.block_old_event_alert_age" "" > /dev/null
$CAKE Admin setSetting "MISP.incoming_tags_disabled_by_default" false > /dev/null
$CAKE Admin setSetting "MISP.maintenance_message" "Great things are happening! MISP is undergoing maintenance, but will return shortly. You can contact the administration at \$email. " > /dev/null
$CAKE Admin setSetting "MISP.footermidleft" "This is an autogenerated VM" > /dev/null
$CAKE Admin setSetting "MISP.footermidright" "Please configure accordingly and do not use in production. 3fb8269" > /dev/null
$CAKE Admin setSetting "MISP.welcome_text_top" "Autogenerated VM" > /dev/null
$CAKE Admin setSetting "MISP.download_attachments_on_load" true > /dev/null
$CAKE Admin setSetting "MISP.title_text" "MISP" > /dev/null
$CAKE Admin setSetting "MISP.terms_download" false > /dev/null
$CAKE Admin setSetting "MISP.showorgalternate" false > /dev/null
$CAKE Admin setSetting "MISP.event_view_filter_fields" "id, uuid, value, comment, type, category, Tag.name" > /dev/null
$CAKE Admin setSetting "MISP.welcome_text_bottom" "Use for testing purposes only, production-use considered harmful." > /dev/null


# Force defaults to make MISP Server Settings less GREEN
$CAKE Admin setSetting "Security.password_policy_length" 12 > /dev/null
$CAKE Admin setSetting "Security.password_policy_complexity" '/^((?=.*\d)|(?=.*\W+))(?![\n])(?=.*[A-Z])(?=.*[a-z]).*$|.{16,}/' > /dev/null

# Tune global time outs
$CAKE Admin setSetting "Session.autoRegenerate" 0 > /dev/null
$CAKE Admin setSetting "Session.timeout" 600 > /dev/null
$CAKE Admin setSetting "Session.cookie_timeout" 3600 > /dev/null

echo "--- Generating a GPG encryption key… ---"
sudo apt-get install -y rng-tools haveged > /dev/null 2>&1
sudo -u www-data mkdir $PATH_TO_MISP/.gnupg
sudo chmod 700 $PATH_TO_MISP/.gnupg
cat >/tmp/gen-key-script <<EOF
    %echo Generating a default key
    Key-Type: default
    Key-Length: $GPG_KEY_LENGTH
    Subkey-Type: default
    Name-Real: $GPG_REAL_NAME
    Name-Comment: $GPG_COMMENT
    Name-Email: $GPG_EMAIL_ADDRESS
    Expire-Date: 0
    Passphrase: $GPG_PASSPHRASE
    # Do a commit here, so that we can later print "done"
    %commit
    %echo done
EOF
sudo -u www-data gpg --homedir $PATH_TO_MISP/.gnupg --batch --gen-key /tmp/gen-key-script
rm /tmp/gen-key-script
# And export the public key to the webroot
sudo -u www-data sh -c "gpg --homedir $PATH_TO_MISP/.gnupg --export --armor $GPG_EMAIL_ADDRESS > $PATH_TO_MISP/app/webroot/gpg.asc"

echo "--- Making the background workers start on boot… ---"
sudo chmod 755 $PATH_TO_MISP/app/Console/worker/start.sh
# With systemd:
# sudo cat > /etc/systemd/system/workers.service  <<EOF
# [Unit]
# Description=Start the background workers at boot
#
# [Service]
# Type=forking
# User=www-data
# ExecStart=$PATH_TO_MISP/app/Console/worker/start.sh
#
# [Install]
# WantedBy=multi-user.target
# EOF
# sudo systemctl enable workers.service > /dev/null
# sudo systemctl restart workers.service > /dev/null

# With initd:
if [ ! -e /etc/rc.local ]
then
    echo '#!/bin/sh -e' | sudo tee -a /etc/rc.local
    echo 'exit 0' | sudo tee -a /etc/rc.local
    chmod u+x /etc/rc.local
fi


# redis-server requires the following /sys/kernel tweak
sed -i -e '$i \echo never > /sys/kernel/mm/transparent_hugepage/enabled\n' /etc/rc.local
sed -i -e '$i \echo 1024 > /proc/sys/net/core/somaxconn\n' /etc/rc.local
sed -i -e '$i \sysctl vm.overcommit_memory=1\n' /etc/rc.local
sed -i -e '$i \sudo -u www-data bash /var/www/MISP/app/Console/worker/start.sh > /tmp/worker_start_rc.local.log\n' /etc/rc.local
sed -i -e '$i \git_dirs="/usr/local/src/misp-modules/ /var/www/misp-dashboard /usr/local/src/faup /usr/local/src/mail_to_misp /usr/local/src/misp-modules /usr/local/src/viper /var/www/misp-dashboard"\n' /etc/rc.local
sed -i -e '$i \for d in $git_dirs; do\n' /etc/rc.local
sed -i -e '$i \    echo "Updating ${d}" >> /tmp/git-update_rc.local.log\n' /etc/rc.local
sed -i -e '$i \    cd $d && sudo git pull  >> /tmp/git-update_rc.local.log &\n' /etc/rc.local
sed -i -e '$i \done\n' /etc/rc.local
sed -i -e '$i \sudo -u www-data /var/www/MISP/venv/bin/misp-modules -l 0.0.0.0 -s > /tmp/misp-modules_rc.local.log 2> /dev/null &\n' /etc/rc.local
sed -i -e '$i \sudo -u www-data bash /var/www/misp-dashboard/start_all.sh > /tmp/misp-dashboard_rc.local.log\n' /etc/rc.local
sed -i -e '$i \sudo -u misp /usr/local/src/viper/viper-web -p 8888 -H 0.0.0.0 > /tmp/viper-web_rc.local.log &\n' /etc/rc.local


echo "--- Installing MISP modules… ---"
sudo apt-get install -y libpq5 libjpeg-dev libfuzzy-dev > /dev/null 2>&1
cd /usr/local/src/
sudo git clone https://github.com/MISP/misp-modules.git
sudo chown -R www-data:www-data misp-modules
cd misp-modules
# pip3 install
sudo -H -u www-data ${PATH_TO_MISP}/venv/bin/pip install -I -r REQUIREMENTS > /dev/null 2>&1
sudo -H -u www-data ${PATH_TO_MISP}/venv/bin/pip install -I . > /dev/null 2>&1
sudo -H -u www-data ${PATH_TO_MISP}/venv/bin/pip install lief maec pathlib pymisp python-magic wand > /dev/null 2>&1
sudo -H -u www-data ${PATH_TO_MISP}/venv/bin/pip install git+https://github.com/kbandla/pydeep.git > /dev/null 2>&1
# install STIX2.0 library to support STIX 2.0 export:
cd ${PATH_TO_MISP}/cti-python-stix2
sudo -H -u www-data ${PATH_TO_MISP}/venv/bin/pip install -I . > /dev/null 2>&1
# With systemd:
# sudo cat > /etc/systemd/system/misp-modules.service  <<EOF
# [Unit]
# Description=Start the misp modules server at boot
#
# [Service]
# Type=forking
# User=www-data
# ExecStart=/bin/sh -c 'misp-modules -l 0.0.0.0 -s &'
#
# [Install]
# WantedBy=multi-user.target
# EOF
# sudo systemctl enable misp-modules.service > /dev/null
# sudo systemctl restart misp-modules.service > /dev/null

# With initd:
# sudo sed -i -e '$i \sudo -u www-data misp-modules -l 0.0.0.0 -s &\n' /etc/rc.local

echo "--- Installing viper-framework ---"
cd /usr/local/src/
apt-get install -y libssl-dev swig python3-ssdeep p7zip-full unrar-free sqlite python3-pyclamd exiftool radare2 > /dev/null 2>&1
git clone https://github.com/viper-framework/viper.git
cd viper
virtualenv -p python3 venv > /dev/null 2>&1
git submodule update --init --recursive > /dev/null 2>&1
./venv/bin/pip install scrapy SQLAlchemy PrettyTable python-magic > /dev/null 2>&1
./venv/bin/pip install -r requirements.txt > /dev/null 2>&1
sed -i '1 s/^.*$/\#!\/usr\/local\/src\/viper\/venv\/bin\/python/' viper-cli
sed -i '1 s/^.*$/\#!\/usr\/local\/src\/viper\/venv\/bin\/python/' viper-web
wget -O requirements-web.txt https://raw.githubusercontent.com/SteveClement/viper/56585c97cf236ef4b2f202c55e4c1148b856ed04/requirements-web.txt > /dev/null 2>&1
./venv/bin/pip install -r requirements-web.txt > /dev/null 2>&1
sudo -u misp /usr/local/src/viper/viper-cli -h > /dev/null 2>&1
sudo -u misp /usr/local/src/viper/viper-web -p 8888 -H 0.0.0.0 &
echo 'PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/usr/local/src/viper"' |sudo tee /etc/environment

echo "--- Installing mail2misp ---"
cd /usr/local/src/
apt-get install -y cmake > /dev/null 2>&1
git clone https://github.com/MISP/mail_to_misp.git > /dev/null 2>&1
git clone https://github.com/stricaud/faup.git faup > /dev/null 2>&1
chown -R misp:misp faup mail_to_misp
cd faup/build
sudo -u misp cmake .. > /dev/null 2>&1 && sudo -u misp make > /dev/null 2>&1
make install > /dev/null 2>&1
ldconfig
cd ../../
cd mail_to_misp
virtualenv -p python3 venv > /dev/null 2>&1
./venv/bin/pip install -r requirements.txt > /dev/null 2>&1
sudo -u misp cp mail_to_misp_config.py-example mail_to_misp_config.py

echo "--- Installing vbox guest additions ---"
apt-get install -y dkms virtualbox-guest-additions-iso virtualbox-guest-dkms > /dev/null 2>&1
mount -o loop /usr/share/virtualbox/VBoxGuestAdditions.iso /mnt
yes|sh /mnt/VBoxLinuxAdditions.run
umount /mnt

echo "--- Generating Certificate ---"
openssl req -newkey rsa:4096 -days 365 -nodes -x509 -subj "/C=LU/ST=/L=Luxembourg/O=CIRCL/OU=VM AutoGen/CN=localhost/emailAddress=admin@admin.test" -keyout /etc/ssl/private/misp.local.key -out /etc/ssl/private/misp.local.crt > /dev/null 2>&1

echo "--- Setting the permissions… ---"
sudo chown -R www-data:www-data $PATH_TO_MISP
sudo chmod -R 750 $PATH_TO_MISP
sudo chmod -R g+ws $PATH_TO_MISP/app/tmp
sudo chmod -R g+ws $PATH_TO_MISP/app/files
sudo chmod -R g+ws $PATH_TO_MISP/app/files/scripts/tmp

echo "--- Restarting Apache… ---"
sudo systemctl restart apache2 > /dev/null 2>&1
sleep 5

echo "--- Updating the galaxies… ---"
sudo -E $PATH_TO_MISP/app/Console/cake userInit -q > /dev/null
AUTH_KEY=$(mysql -u $DBUSER_MISP -p$DBPASSWORD_MISP misp -e "SELECT authkey FROM users;" | tail -1)
echo ${AUTH_KEY} > /tmp/AUTH_KEY.txt
# Update the galaxies…
$CAKE Admin updateGalaxies > /dev/null 2>&1

# Updating the taxonomies…
$CAKE Admin updateTaxonomies > /dev/null 2>&1

# Updating the warning lists…
##$CAKE Admin updateWarningLists
curl --header "Authorization: $AUTH_KEY" --header "Accept: application/json" --header "Content-Type: application/json" -o /dev/null -s -X POST http://127.0.0.1/warninglists/update > /dev/null 2>&1

# Updating the notice lists…
## sudo $CAKE Admin updateNoticeLists
curl --header "Authorization: $AUTH_KEY" --header "Accept: application/json" --header "Content-Type: application/json" -o /dev/null -s -X POST http://127.0.0.1/noticelists/update > /dev/null 2>&1

# Updating the object templates…
##sudo $CAKE Admin updateObjectTemplates
curl --header "Authorization: $AUTH_KEY" --header "Accept: application/json" --header "Content-Type: application/json" -o /dev/null -s -X POST http://127.0.0.1/objectTemplates/update > /dev/null 2>&1

# Set python virtualenenv to be used
$CAKE Admin setSetting "MISP.python_bin" "${PATH_TO_MISP}/venv/bin/python" > /dev/null 2>&1

echo "--- Enabling MISP new pub/sub feature (ZeroMQ)… ---"
sudo apt-get install -y pkg-config python-redis python-zmq python3-zmq > /dev/null 2>&1

echo "--- Configuring viper ---"
sed -i "s/^misp_url\ =/misp_url\ =\ http:\/\/localhost/g" ~/.viper/viper.conf
sed -i "s/^misp_key\ =/misp_key\ =\ $AUTH_KEY/g" ~/.viper/viper.conf
# Setting viper-web admin user password to 'Password1234'
sqlite3 ~/.viper/admin.db 'UPDATE auth_user SET password="pbkdf2_sha256$100000$iXgEJh8hz7Cf$vfdDAwLX8tko1t0M1TLTtGlxERkNnltUnMhbv56wK/U="'

echo "--- Configuring mail2misp ---"
sudo sed -i "s/^misp_url\ =\ 'YOUR_MISP_URL'/misp_url\ =\ 'http:\/\/localhost'/g" /usr/local/src/mail_to_misp/mail_to_misp_config.py
sudo sed -i "s/^misp_key\ =\ 'YOUR_KEY_HERE'/misp_key\ =\ '$AUTH_KEY'/g" /usr/local/src/mail_to_misp/mail_to_misp_config.py

echo "--- Installing asciidoctor-pdf ---"
gem install asciidoctor-pdf --pre > /dev/null 2>&1
gem install pygments.rb > /dev/null 2>&1

echo "--- Setting up jupyter notebook ---"
sudo apt purge -f jupyter-notebook -y # Do not remove this purge, we *do not want* the system version
sudo -H -u www-data ${PATH_TO_MISP}/venv/bin/pip install -I -U jupyter
echo $AUTH_KEY > $PATH_TO_MISP/PyMISP/docs/tutorial/apikey
sed -i -e '$i \sudo -u www-data HOME="/var/www/MISP/PyMISP/" /var/www/MISP/venv/bin/jupyter-notebook --port=8889 --ip=0.0.0.0 --no-browser --NotebookApp.token='' --NotebookApp.notebook_dir=/var/www/MISP/PyMISP/docs/tutorial/ --NotebookApp.iopub_data_rate_limit=0 > /tmp/jupyter_rc.local.log &\n' /etc/rc.local

echo "--- Ignoring filemode on all submodules ---"
cd $PATH_TO_MISP
sudo -u www-data git submodule foreach --recursive git config core.filemode false > /dev/null 2>&1

echo "--- Setting Baseurl and making sure Sessions do NOT auto regenerate ---"
$CAKE Baseurl "" > /dev/null 2>&1
$CAKE Admin setSetting "Session.autoRegenerate" 0 > /dev/null 2>&1

echo "\e[32mMISP is ready\e[0m"
echo "Login and passwords for the MISP image are the following:"
echo "Web interface (default network settings): $MISP_BASEURL"
echo "MISP admin:  admin@admin.test/admin"
echo "Shell/SSH: misp/Password1234"
echo "MySQL:  $DBUSER_ADMIN/$DBPASSWORD_ADMIN - $DBUSER_MISP/$DBPASSWORD_MISP"
echo "MySQL:  $DBUSER_ADMIN/$DBPASSWORD_ADMIN - $DBUSER_MISP/$DBPASSWORD_MISP" > ~/mysql.txt

echo "--- Setting the permissions… ---"
chown -R www-data:www-data $PATH_TO_MISP
chmod -R 750 $PATH_TO_MISP
chmod -R g+ws $PATH_TO_MISP/app/tmp
chmod -R g+ws $PATH_TO_MISP/app/files
chmod -R g+ws $PATH_TO_MISP/app/files/scripts/tmp
chmod 700 $PATH_TO_MISP/.gnupg
chown -R misp:misp ~misp/.viper
chown misp:misp ~/mysql.txt

TIME_END=$(date +%s)
TIME_DELTA=$(expr ${TIME_END} - ${TIME_START})

echo "The generation took ${TIME_DELTA} seconds"
