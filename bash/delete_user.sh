#!/bin/bash
echo 'enter username:'
read un

if id -u $un >/dev/null 2>&1; then
        echo "Deleting user: $un"
        sudo userdel -r $un
        #sudo bash /home/ec2-user/build_developer_auth_keys.sh
else
        echo "User $un does not exist"
fi
