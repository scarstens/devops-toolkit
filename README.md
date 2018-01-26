# Devops Toolkit
Toolkit for devops engineers trying to build and host web applications in the cloud (or locally!)

## Building a Node App on AWS
These instructions go over setting up an EC2 instance that hosts your Node App on Amazon AWS, using an EC2 instance (which can be running on free teir). This NodeJS app out of the box will be running express with a simple hello world echo output. It uses Nginx as a reverse proxy to handle routing and SSL certifications for HTTPS (so you don't need to worry about HTTPS routing in your node app). Its also prepared to load standard resources (like css files) directly from the server. 

[Node on AWS Instructions (WIP)](node-ec2.md)

## Building a WordPress App on AWS
Description coming soon...
```bash
git clone https://github.com/scarstens/devops-toolkit ; sudo sg www-data -c 'bash devops-toolkit/beta/wordpress-ec2.sh'
```

## Using Certbot (LetsEncrypt)
Note, is this is using HTTP_1 checker, since as of today the default checker has a security issue. Second thing to note is that you should confirm the webroot-path in case yours differes, and update the domains to match your actual domains.

Before you run this command, remember that this assumes you are using Nginx to proxy your HTTP connections to browser clients. Secondly, that you need to have an Nginx config where the "server_name" field matches the domain name(s) that you are requesting signed SSL certificates for. This allows the command to automaitcally update your nginx config to load the certificates for you.

```bash
sudo certbot --authenticator webroot --webroot-path /var/www/wordpress/htdocs --installer nginx -d yourdomain.com -d sub.yourdomain.com
```
