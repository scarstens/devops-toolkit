# Devops Toolkit
Toolkit for devops engineers trying to build and host web applications in the cloud (or locally!)

## Using Certbot (LetsEncrypt)
First thing of note, is this is using HTTP_1 checker, since as of today the default checker has a security issue. Second thing to note is that you should confirm the webroot-path in case yours differes, and update the domains to match your actual domains.

```bash
sudo certbot --authenticator webroot --webroot-path /var/www/wordpress/htdocs --installer nginx -d yourdomain.com -d sub.yourdomain.com
```
