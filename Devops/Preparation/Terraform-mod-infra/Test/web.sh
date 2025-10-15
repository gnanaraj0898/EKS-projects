#!/bin/bash

sudo yum install wget unzip httpd -y

sudo systemctl start httpd
sudo systemctl enable httpd

mkdir -p /tmp/webfiles
cd /tmp/webfiles

wget https://www.tooplate.com/zip-templates/2137_barista_cafe.zip
unzip 2137_barista_cafe.zip
sudo cp -r 2137_barista_cafe/* /var/www/html/

systemctl restart httpd

rm -rf /tmp/webfiles