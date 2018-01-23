#!/usr/bin/env bash
# TODO: handle sudo unable to resolve host
sudo true
## TODO: grep just the hostname out of this and store in a var
## TODO: use the var and echo a line into the /etc/hosts file with 127.0.0.1 $VAR

# LEMP
export MYSQL_USER="nginx"
export MYSQL_PASS=$(date +%s | sha256sum | base64 | head -c 32 ; echo)
export PUBLIC_IP_DASHES=$(echo $PUBLIC_IP | tr  "."  "-")
export DOMAIN="ec2-$PUBLIC_IP_DASHES.us-east-2.compute.amazonaws.com"
export GHUSERNAME=""
export GHTOKEN=""
export WP_VERSION="latest"
export DB_NAME="wordpress"
export DB_NAME=${DB_NAME//[\\\/\.\<\>\:\"\'\|\?\!\*-]/}

sudo apt-get update
sudo apt-get upgrade
sudo usermod -aG www-data ubuntu -y

sudo apt-get install nginx -y
sudo apt-get install mariadb-server mariadb-client -y

# secure mysql from install defaults
sudo mysql -e "CREATE USER '${MYSQL_USER}'@'localhost' IDENTIFIED BY '${MYSQL_PASS}';"
sudo mysql -e "GRANT ALL PRIVILEGES ON * . * TO '${MYSQL_USER}'@'localhost';"
sudo mysql -e "FLUSH PRIVILEGES;"
echo "Created MySQL User / PW:"
echo ${MYSQL_USER}
echo ${MYSQL_PASS}

sudo mysql -t<<'string'
UPDATE mysql.user SET Password=PASSWORD('root') WHERE User='root';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
string

sudo apt-get install php-fpm php-mysql -y
sudo mkdir -p /var/www/wordpress/htdocs
sudo mkdir -p /var/www/wordpress/logs
sudo touch /var/www/wordpress/logs/error.log
sudo chown -R www-data:www-data /var/www
sudo rm /etc/nginx/sites-enabled/default

# Build nginx configuration default the public IP to the server name
sudo tee /etc/nginx/sites-available/wordpress <<EOF
server {
    listen      80;
    listen [::]:80;
    listen 443 ssl;
    listen [::]:443 ssl;
    error_log /var/www/wordpress/logs/error.log;
	root /var/www/wordpress/htdocs;

	# Add index.php to the list if you are using PHP
	index index.php index.html index.htm index.nginx-debian.html;

	server_name ${DOMAIN};

	location / {
		try_files \$uri \$uri/ /index.php?q=\$uri&\$args;
	}

    location ~ \.php$ {
        try_files \$uri =404;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:/var/run/php/php7.0-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param  SCRIPT_FILENAME  \$document_root\$fastcgi_script_name;
    }

    if (\$scheme != "https") {
        return 301 https://\$host\$request_uri;
    }

    # indicate locations of SSL key files.
    ssl_certificate /var/www/wordpress/certs/webapp.crt;
    ssl_certificate_key /var/www/wordpress/certs/webapp.key;
}
EOF

# Symlink the config into the enabled Nginx dir so it loads by default
sudo ln -s /etc/nginx/sites-available/wordpress /etc/nginx/sites-enabled/wordpress

# Build SSL certs
mkdir -p /var/www/wordpress/certs
cd /var/www/wordpress/certs
# Create cert builder script
sudo tee /var/www/wordpress/certs/self-signed-tls.sh <<'FILE'
#!/bin/bash

# Directories
cur=`pwd`
tmp=`mktemp -d`
scriptName=`basename $0`

# Certificate Variables
OUTPATH="./"
VERBOSE=0
DURATION=3650 # 10 years

safeExit() {
  if [ -d $tmp ]; then
    if [ $VERBOSE -eq 1 ]; then
      echo "Removing temporary directory '${tmp}'"
    fi
    rm -rf $tmp
  fi

  trap - INT TERM EXIT
  exit
}

# Help Screen
help() {
  echo -n "${scriptName} [OPTIONS] -c=US --state=California

Generate self-signed TLS certificate using OpenSSL

 Options:
  -c|--country         Country Name (2 letter code)
  -s|--state           State or Province Name (full name)
  -l|--locality        Locality Name (eg, city)
  -o|--organization    Organization Name (eg, company)
  -u|--unit            Organizational Unit Name (eg, section)
  -n|--common-name     Common Name (e.g. server FQDN or YOUR name)
  -e|--email           Email Address
  -p|--path            Path to output generated keys
  -d|--duration        Validity duration of the certificate (in days)
  -h|--help            Display this help and exit
  -v|--verbose         Verbose output
"
}

# Test output path is valid
testPath() {
  if [ ! -d $OUTPATH ]; then
    echo "The specified directory \"${OUTPATH}\" does not exist"
    exit 1
  fi
}

# Process Arguments
while [ "$1" != "" ]; do
  PARAM=`echo $1 | awk -F= '{print $1}'`
  VALUE=`echo $1 | awk -F= '{print $2}'`
  case $PARAM in
    -h|--help) help; safeExit ;;
    -c|--country) C=$VALUE ;;
    -s|--state) ST=$VALUE ;;
    -l|--locality) L=$VALUE ;;
    -o|--organization) O=$VALUE ;;
    -u|--unit) OU=$VALUE ;;
    -n|--common-name) CN=$VALUE ;;
    -e|--email) emailAddress=$VALUE ;;
    -p|--path) OUTPATH=$VALUE; testPath ;;
	-d|--duration) DURATION=$VALUE ;;
    -v|--verbose) VERBOSE=1 ;;
    *) echo "ERROR: unknown parameter \"$PARAM\""; help; exit 1 ;;
  esac
  shift
done

# Prompt for variables that were not provided in arguments
checkVariables() {
  # Country
  if [ -z $C ]; then
    echo -n "Country Name (2 letter code) [AU]:"
    read C
  fi

  # State
  if [ -z $ST ]; then
    echo -n "State or Province Name (full name) [Some-State]:"
    read ST
  fi

  # Locality
  if [ -z $L ]; then
    echo -n "Locality Name (eg, city) []:"
    read L
  fi

  # Organization
  if [ -z $O ]; then
    echo -n "Organization Name (eg, company) [Internet Widgits Pty Ltd]:"
    read O
  fi

  # Organizational Unit
  if [ -z $OU ]; then
    echo -n "Organizational Unit Name (eg, section) []:"
    read OU
  fi

  # Common Name
  if [ -z $CN ]; then
    echo -n "Common Name (e.g. server FQDN or YOUR name) []:"
    read CN
  fi

  # Common Name
  if [ -z $emailAddress ]; then
    echo -n "Email Address []:"
    read emailAddress
  fi
}

# Show variable values
showVals() {
  echo "Country: ${C}";
  echo "State: ${ST}";
  echo "Locality: ${L}";
  echo "Organization: ${O}";
  echo "Organization Unit: ${OU}";
  echo "Common Name: ${CN}";
  echo "Email: ${emailAddress}";
  echo "Output Path: ${OUTPATH}";
  echo "Certificate Duration (Days): ${DURATION}";
  echo "Verbose: ${VERBOSE}";
}

# Init
init() {
  cd $tmp
  pwd
}

# Cleanup
cleanup() {
  echo "Cleaning up"
  cd $cur
  rm -rf $tmp
}

buildCsrCnf() {
cat << EOF > ${tmp}/tmp.csr.cnf
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn

[dn]
C=${C}
ST=${ST}
L=${L}
O=${O}
OU=${OU}
CN=${CN}
emailAddress=${emailAddress}
EOF
}

buildExtCnf() {
cat << EOF > ${tmp}/v3.ext
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${CN}
EOF
}

# Build TLS Certificate
build() {
  # Generate CA key & crt
  openssl genrsa -out ${tmp}/tmp.key 2048
  openssl req -x509 -new -nodes -key ${tmp}/tmp.key -sha256 -days ${DURATION} -out ${tmp}/tmp.pem -subj "/C=${C}/ST=${ST}/L=${L}/O=${O}/OU=${OU}/CN=${CN}/emailAddress=${emailAddress}"

  # CSR Configuration
  buildCsrCnf

  # Create v3.ext configuration file
  buildExtCnf

  # Server key
  openssl req -new -sha256 -nodes -out ${OUTPATH}${CN}.csr -newkey rsa:2048 -keyout ${OUTPATH}${CN}.key -config <( cat ${tmp}/tmp.csr.cnf )

  # Server certificate
  openssl x509 -req -in ${OUTPATH}${CN}.csr -CA ${tmp}/tmp.pem -CAkey ${tmp}/tmp.key -CAcreateserial -out ${OUTPATH}${CN}.crt -days ${DURATION} -sha256 -extfile ${tmp}/v3.ext
}

checkVariables
build
# showVals
safeExit
FILE

# Build SSL Keys
sudo bash /var/www/wordpress/certs/self-signed-tls.sh -c="US" -s="US" -l="US" -o="webapp" -u="webapp" -n="webapp" -e="admin@webapp.localhost" -p="/var/www/wordpress/certs/" -d=365

# Reload Nginx
sudo systemctl reload nginx

# Install WP CLI
cd ~ ; curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && sudo mv wp-cli.phar /usr/local/bin/wp && chmod +x /usr/local/bin/wp ;

# Setup WP CLI config
sudo tee /var/www/wordpress/wp-cli.yml <<EOF
path: htdocs
EOF

sudo tee /usr/local/bin/fix-wordpress-permissions <<'FILE'
#!/bin/bash
#
# This script configures WordPress file permissions based on recommendations
# from http://codex.wordpress.org/Hardening_WordPress#File_permissions
#
# Author: Michael Conigliaro <mike [at] conigliaro [dot] org>
#
WP_OWNER=www-data # <-- wordpress owner
WP_GROUP=www-data # <-- wordpress group
WP_ROOT=$1 # <-- wordpress root directory
WS_GROUP=www-data # <-- webserver group

# reset to safe defaults
find ${WP_ROOT} -exec chown ${WP_OWNER}:${WP_GROUP} {} \;
find ${WP_ROOT} -type d -exec chmod 755 {} \;
find ${WP_ROOT} -type f -exec chmod 644 {} \;

# allow wordpress to manage wp-config.php (but prevent world access)
chgrp ${WS_GROUP} ${WP_ROOT}/wp-config.php
chmod 660 ${WP_ROOT}/wp-config.php

# allow wordpress to manage wp-content
find ${WP_ROOT}/wp-content -exec chgrp ${WS_GROUP} {} \;
find ${WP_ROOT}/wp-content -type d -exec chmod 775 {} \;
find ${WP_ROOT}/wp-content -type f -exec chmod 664 {} \;
FILE

chown ubuntu:ubuntu /usr/local/bin/fix-wordpress-permissions
chmod +x /usr/local/bin/fix-wordpress-permissions

# We use JQ to manage json in bash
sudo apt-get install jq

# Make a database, if we don't already have one
echo -e "\nCreating database '${DB_NAME}' (if it's not already there)"
sudo mysql -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME}"
sudo mysql -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO ${MYSQL_USER}@localhost IDENTIFIED BY '${MYSQL_PASS}';"
sudo mysql -e "FLUSH PRIVILEGES;"

sudo chmod 775 /var/www/wordpress/htdocs
echo "Downloading WordPress [::315]..."
wp core download --version="${WP_VERSION}"
sudo fix-wordpress-permissions $(pwd)
echo "Configuring WordPress [::32]..."
sudo wp --allow-root core config --dbname="${DB_NAME}" --dbuser="${MYSQL_USER}" --dbpass="${MYSQL_PASS}" --extra-php <<'PHP'
if( ! empty( $_COOKIE['debug'] )) {
    define( 'WP_DEBUG_DISPLAY', true );
    ini_set('display_errors','On');
    define( 'WP_DEBUG', true );
    ini_set('error_reporting', E_ALL );
} else {
    define( 'WP_DEBUG_DISPLAY', false );
    ini_set('display_errors','Off');
}
PHP
sudo fix-wordpress-permissions $(pwd)

echo "Installing WordPress [::364]..."
wp core multisite-install --subdomains --url="${DOMAIN}" --quiet --title="" --admin_email="webapp@wordpress.local"
echo "Minifying WordPress install ..."
wp theme delete twentythirteen ; wp theme delete twentyfourteen; wp theme delete twentyfifteen; wp theme delete twentysixteen; wp plugin delete hello; wp plugin delete akismet;
