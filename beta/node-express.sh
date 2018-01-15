#!/usr/bin/env bash
sudo apt-get update

# Allow apt-get to fetch version 8 of nodejs
curl -sL https://deb.nodesource.com/setup_8.x | sudo -E bash -
sudo apt-get install -y nodejs
sudo apt-get install -y build-essential

#Install Node and Node tools and Nginx for web reverse proxy
sudo apt-get install -y nginx

# Make sure all packages are up to date
sudo apt-get update && sudo apt-get -y upgrade
# Setup Nginx
systemctl status nginx

# Prepare the application
sudo mkdir -p /var/www/nodeapp
# Existing Apps
#sudo git clone https://github.com/myuser/myrepo /var/www/nodeapp
cd /var/www/nodeapp
# Demo express App
npm init
npm install express --save

tee index.js <<EOF
var express = require('express');
var app = express();
app.get('/', function (req, res) {
  res.send('Hello World!');
});
app.listen(3000, function () {
  console.log('Example app listening on port 3000!');
});
EOF

# Install PM2 used to run node apps and keep them running
sudo chown -R $USER:$(id -gn $USER) /home/ubuntu/.config
sudo chown -R $USER:$(id -gn $USER) /var/www
sudo chown -R $USER:$(id -gn $USER) /home/ubuntu/.npm/_logs

sudo npm install pm2 -g
pm2 list
# To run npm its like this
#sudo pm2 start npm --name="node-app" -- run dev
# Sample app runs index.js
pm2 start --name="nodeapp" index.js
# Startup command starts this node app in case the server restarts, on startup
sudo pm2 startup
sudo env PATH=$PATH:/usr/bin /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u ubuntu --hp /home/ubuntu
# not sure why, but this fails the first time and works the second time
sudo env PATH=$PATH:/usr/bin /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u ubuntu --hp /home/ubuntu

# Build nginx reverse proxy config for node
sudo rm /etc/nginx/sites-enabled/default
sudo tee /etc/nginx/sites-available/nodeapp <<'EOF'
server {
	server_name _;
	listen 80;
    listen 443 ssl;
	location / {
		proxy_pass http://127.0.0.1:3000;
		proxy_http_version 1.1;
		proxy_set_header Upgrade $http_upgrade;
		proxy_set_header Connection 'upgrade';
		proxy_set_header Host $host;
		proxy_cache_bypass $http_upgrade;
	}
}
EOF
ln -s /etc/nginx/sites-available/nodeapp /etc/nginx/sites-enabled/nodeapp
sudo nginx -t

# Reload Nginx
sudo systemctl reload nginx

# Use this section once you have a domain to generate SSL certificates and apply them to nginx config
#sudo apt-get update
#sudo apt-get install software-properties-common
#sudo add-apt-repository -y ppa:certbot/certbot
#sudo apt-get update
#sudo apt-get install python-certbot-nginx
#sudo certbot --nginx -d layouts.onecms.io