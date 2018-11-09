#!/bin/bash
# Install Docker
yum install -y yum-utils \
  device-mapper-persistent-data \
  lvm2

yum-config-manager \
    --add-repo \
    https://download.docker.com/linux/centos/docker-ce.repo

yum-config-manager --disable docker-ce-edge

yum install -y docker-ce

systemctl start docker

# Start Kura in Docker 
#(do not exit the terminal session or close the OSGi console or it will kill the container)
docker run -ti -p 8080:8080 ctron/kura-emulator:3.0.0
