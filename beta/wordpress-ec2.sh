#!/usr/bin/env bash
echo "Fixing unable to resolve hosts when VPC doesn't allow DNS hostnames..."
echo "127.0.0.1 $(hostname)" | sudo tee -a /etc/hosts 2>&1 /dev/null

echo "Staying up to date with apt update and upgrade..."
sudo apt-get update 2>&1 /dev/null
sudo apt-get upgrade -y 2>&1 /dev/null

export DOMAIN=$1
if [ -z "$DOMAIN" ] ; then
export DOMAIN=$(curl -s http://169.254.169.254/latest/meta-data/public-hostname)
fi
read -p "Override domain? (currently ${DOMAIN}): " DOMAIN_OVERRIDE
if [ ! -z "$DOMAIN_OVERRIDE" ] ; then
export DOMAIN=${DOMAIN_OVERRIDE}
fi
echo "Domain set to ${DOMAIN}"
export DOMAIN_PRIVATE=$(curl -s http://169.254.169.254/latest/meta-data/hostname)
export IPV4=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
export IPV4_PRIVATE=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)

echo "Adding domains and IP's to local hosts file"
echo "127.0.0.1 ${DOMAIN}" | sudo tee -a /etc/hosts 2>&1 /dev/null
echo "127.0.0.1 ${DOMAIN_PRIVATE}" | sudo tee -a /etc/hosts 2>&1 /dev/null
echo "127.0.0.1 ${IPV4}" | sudo tee -a /etc/hosts 2>&1 /dev/null
echo "127.0.0.1 ${IPV4_PRIVATE}" | sudo tee -a /etc/hosts 2>&1 /dev/null

echo "Build all the params you need for the install..."
## TODO: allow passing these vars into the script
export MYSQL_USER="nginx"
export MYSQL_PASS=$(date +%s | sha256sum | base64 | head -c 32 ; echo)
export WP_VERSION="latest"
export DB_NAME="wordpress"
export DB_NAME=${DB_NAME//[\\\/\.\<\>\:\"\'\|\?\!\*-]/}

echo "Install the LEMP stack..."
echo " Start with nginx, and validate it built a proper config file..."
sudo apt-get install nginx -y
sudo nginx -t
echo " Install MySQL (mariadb for btter performance)..."
sudo apt-get install mariadb-server mariadb-client -y

echo " Securing MySQL defaults..."
sudo mysql -t<<'string'
UPDATE mysql.user SET Password=PASSWORD('root') WHERE User='root';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
string

echo " Creating new mysql user for application..."
sudo mysql -e "CREATE USER '${MYSQL_USER}'@'localhost' IDENTIFIED BY '${MYSQL_PASS}';"
sudo mysql -e "GRANT ALL PRIVILEGES ON * . * TO '${MYSQL_USER}'@'localhost';"
sudo mysql -e "FLUSH PRIVILEGES;"
echo -e "Created MySQL User / PW:\n${MYSQL_USER} / ${MYSQL_PASS}"


echo "Installing and setting up PHP"
sudo apt-get install php-fpm php-mysql -y
echo " Preparing standing folders and files for PHP/Nginx config"
sudo mkdir -p /var/www/wordpress/htdocs
sudo mkdir -p /var/www/wordpress/logs
sudo mkdir -p /var/www/wordpress/certs
sudo touch /var/www/wordpress/logs/error.log
sudo chown -R www-data:www-data /var/www
sudo chmod -R 0775 /var/www
echo " Removing Nginx default configuration (it conflicts with WordPress configs)"
sudo rm /etc/nginx/sites-enabled/default

echo " Build nginx configuration default the public IP to the server name"
sudo tee /etc/nginx/sites-available/wordpress <<EOF
server {
    listen      80;
    listen [::]:80;
    listen 443 ssl;
    listen [::]:443 ssl;
    error_log /var/www/wordpress/logs/error.log;
    root /var/www/wordpress/htdocs;
    index index.php index.html index.htm index.nginx-debian.html;
    server_name ${DOMAIN} ${DOMAIN_PRIVATE} ${IPV4} ${IPV4_PRIVATE};
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

echo " Symlink the config into the enabled Nginx dir so it loads by default"
sudo ln -s /etc/nginx/sites-available/wordpress /etc/nginx/sites-enabled/wordpress

echo "Build SSL Keys and Certs (mkdir for certs folder was above)..."
sudo bash ~/devops-toolkit/self-signed-tls.sh -c="AA" -s="AA" -l="AA" -o="webapp" -u="webapp" -n="webapp" -e="admin@webapp.localhost" -p="/var/www/wordpress/certs/" -d=365

echo "Reload Nginx..."
sudo systemctl reload nginx

echo "Install WP CLI..."
cd ~ ; curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && sudo mv wp-cli.phar /usr/local/bin/wp && chmod +x /usr/local/bin/wp ;

echo " Setup WP CLI config"
sudo tee /var/www/wordpress/wp-cli.yml <<EOF
path: htdocs
EOF

echo " Setup fix-wordpress-permissions command"
sudo cp ~/devops-toolkit/fix-wordpress-permissions.sh /usr/local/bin/fix-wordpress-permissions
sudo chown ubuntu:ubuntu /usr/local/bin/fix-wordpress-permissions
sudo chmod +x /usr/local/bin/fix-wordpress-permissions

echo "We use JQ to manage json in bash, installing..."
sudo apt-get install jq -y

echo "Make a database, if we don't already have one..."
echo -e "\nCreating database '${DB_NAME}' (if it's not already there)"
sudo mysql -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME}"
sudo mysql -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO ${MYSQL_USER}@localhost IDENTIFIED BY '${MYSQL_PASS}';"
sudo mysql -e "FLUSH PRIVILEGES;"

echo "Fixing htdocs permissions so WP-CLI can install WordPress..."
sudo chmod 775 /var/www/wordpress/htdocs

echo "Downloading WordPress..."
cd /var/www/wordpress/htdocs
sudo -u www-data -i -- wp core download --version="${WP_VERSION}"
sudo fix-wordpress-permissions $(pwd)
echo "Configuring WordPress..."
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

echo "Installing WordPress..."
sudo -u www-data -i -- wp core multisite-install --subdomains --url="${DOMAIN}" --quiet --title="" --admin_email="webapp@wordpress.local"
echo "Minifying WordPress install ..."
sudo -u www-data -i -- wp theme delete twentythirteen ; sudo -u www-data -i -- wp theme delete twentyfourteen; sudo -u www-data -i -- wp theme delete twentyfifteen; sudo -u www-data -i -- wp theme delete twentysixteen; sudo -u www-data -i -- wp plugin delete hello; sudo -u www-data -i -- wp plugin delete akismet;

echo "Testing Install (likely see redirect for multisite registration of unknown private domain)..."
curl -v -k https://${DOMAIN_PRIVATE}

echo "Summary of install variables:"
echo -e "Created MySQL User / PW:\n${MYSQL_USER} / ${MYSQL_PASS}"
echo "PUBLIC_IP_DASHES=${PUBLIC_IP_DASHES}"
echo "DOMAIN=${DOMAIN}"
echo "WP_VERSION=${WP_VERSION}"
echo "DB_NAME=${DB_NAME}"
echo ""
echo "Next steps are to purchase a domain, create an A record to the public IP, update the nginx config with the domain name(s), and then run certbot script from devops toolkit readme example."
