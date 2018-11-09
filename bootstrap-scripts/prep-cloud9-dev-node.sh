#!/bin/bash

sudo yum erase cloudera-data-science-workbench # cdsw docker version incompatible with cloud9
sudo yum autoremove
sudo yum -y install epel-release
sudo yum -y update
sudo yum -y install gcc gcc-c++ make tmux ncurses-devel mlocate docker git jq
curl --silent --location https://rpm.nodesource.com/setup_8.x | sudo bash -
sudo yum -y install nodejs
sudo groupadd docker

exit 0
