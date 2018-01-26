#!/bin/bash
echo "Applying AWS UBUNTU 16 DEFAULT ADJUSTMENTS FOR WEB APPLICATIONS"
# echo "Fixing unable to resolve hosts when VPC doesn't allow DNS hostnames..."
# echo "127.0.0.1 $(hostname)" | sudo tee -a /etc/hosts 2>&1 /dev/null
echo "Making ubuntu's primary group www-data to match php/nginx group for easier permissioning..."
sudo usermod -g www-data ubuntu
