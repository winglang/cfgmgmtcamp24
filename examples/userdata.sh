#!/bin/bash
yum update -y
amazon-linux-extras install -y nginx1.12
systemctl start nginx
systemctl enable nginx
usermod -a -G nginx-user ec2-user
chown -R ec2-user:nginx-user /var/www
chmod 2775 /var/www
find /var/www -type d -exec chmod 2775 {} \;
find /var/www -type f -exec chmod 0664 {} \;
echo "Ready" > /usr/share/nginx/html/index.html