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
git config --global push.default simple
#sudo pm2 start npm --name="node-app" -- run dev
# Sample app runs index.js
pm2 start --name="nodeapp" index.js
# Startup command starts this node app in case the server restarts, on startup
PM2_STARTUP=$(pm2 startup | grep sudo)
eval $PM2_STARTUP

# Build nginx reverse proxy config for node
sudo rm /etc/nginx/sites-enabled/default
sudo tee /etc/nginx/sites-available/nodeapp <<'EOF'
upstream nodeapp {
    server 127.0.0.1:3000;
}

server {
    server_name _;
    listen 80;
    listen 443 ssl;
    root /var/www/nodeapp;

    location / {
        try_files $uri @nodeapp;
    }

    location @nodeapp {
        proxy_pass http://nodeapp;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        # Following is necessary for Websocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
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
