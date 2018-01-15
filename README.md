# Devops Toolkit
Toolkit for devops engineers trying to build and host web applications in the cloud (or locally!)

## Using Certbot (LetsEncrypt)
Note, is this is using HTTP_1 checker, since as of today the default checker has a security issue. Second thing to note is that you should confirm the webroot-path in case yours differes, and update the domains to match your actual domains.

Before you run this command, remember that this assumes you are using Nginx to proxy your HTTP connections to browser clients. Secondly, that you need to have an Nginx config where the "server_name" field matches the domain name(s) that you are requesting signed SSL certificates for. This allows the command to automaitcally update your nginx config to load the certificates for you.

```bash
sudo certbot --authenticator webroot --webroot-path /var/www/wordpress/htdocs --installer nginx -d yourdomain.com -d sub.yourdomain.com
```
