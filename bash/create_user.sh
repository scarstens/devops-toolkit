#!/bin/bash
echo 'Enter username:'
read un

if id -u $un >/dev/null 2>&1; then
    echo "user exists: $un"
    exit;
fi

# Assumed Else
sudo adduser -g www-data --disabled-password --gecos "" $un
echo "added user: $un"
echo "paste public key:"
read key
sudo su - $un <<USER_COMMANDS
    mkdir .ssh
    chmod 700 .ssh
    touch .ssh/authorized_keys
    chmod 600 .ssh/authorized_keys
    echo "$key" >> .ssh/authorized_keys
USER_COMMANDS

#bash /home/ec2-user/build_developer_auth_keys.sh
echo "key added, user successfully created -- $un:$key"
sudo usermod -aG sudo $un
sudo usermod -g www-data $un
