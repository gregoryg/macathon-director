#!/bin/bash
# 1) Launch the Cloudera Director instance
## Cloudera Director with local repo and web server
# network='totally-bogus'

OWNER_TAG=${OWNER_TAG:=${USER}}  # example: jsmith
SSH_USER="${SSH_USER:=centos}" # examples: jsmith/centos/ec2-user
INSTANCE_NAME=${INSTANCE_NAME:=abc-director} # example: js-director
ZONE=${ZONE:=us-central1-c} # REPLACE with zone
SSH_PRIVATE_KEYPATH_GCP=${SSH_PRIVATE_KEYPATH_GCP:=~/.ssh/my-google-key}
IMAGE_FAMILY=${IMAGE_FAMILY:=centos-7} # REPLACE with centos-7 or rhel-7
IMAGE_PROJECT=${IMAGE_PROJECT:=centos-cloud}
NETWORK=${NETWORK:=locked-down}
GCLOUD_CONFIG=${GCLOUD_CONFIG:=default} # see: gcloud config list

### Do not edit below this line

if [ ${IMAGE_FAMILY} == "rhel-7" ] ; then
    IMAGE_PROJECT=rhel-cloud
fi

echo """Using the following values
Gcloud CLI config: ${GCLOUD_CONFIG}
Owner tag: ${OWNER_TAG}
Zone: ${ZONE}
Instance name: ${INSTANCE_NAME}
Image family / project: ${IMAGE_FAMILY} / ${IMAGE_PROJECT}
Network: ${NETWORK}
SSH User: ${SSH_USER}
SSH private key: ${SSH_PRIVATE_KEYPATH_GCP}
"""
read -p  "Proceed? [Y/n]: " -n 1 -r
# echo

if [[ ! $REPLY =~ ^[Yy]$ ]] ; then
    echo Set the environment variables you require, then run this script again - exiting
    exit 1
fi


echo 'Launching Cloudera Director instance'
info=$(gcloud compute instances create ${INSTANCE_NAME} \
              --zone ${ZONE} \
              --image-family ${IMAGE_FAMILY} \
              --image-project centos-cloud \
              --machine-type n1-standard-2 \
              --labels owner=${OWNER_TAG} \
              --metadata owner=${OWNER_TAG} \
              --network ${NETWORK} \
              --format="value(networkInterfaces[0].accessConfigs[0].natIP:label=EXTERNAL_IP,networkInterfaces[0].networkIP:label=INTERNAL_IP,status)")
if [ "$?" != 0 ] ; then
    echo Error creating the instance
    exit 1
fi

dirip=`echo $info | cut -d' ' -f1`
echo Director external IP is ${dirip}
ssh-keygen -q -R ${dirip}
sshcmd="ssh -tt -i ${SSH_PRIVATE_KEYPATH_GCP} ${SSH_USER}@${dirip} "


echo 'Fixing up the .ssh/config file'
# Create a skeleton config if there is none there already
if [ -x $(dirname "$0")/create-ssh-config.sh ] ; then
    $(dirname "$0")/create-ssh-config.sh
fi

sed -i.bak -E "/^ *Host gcp-director */,/^ *Host / s/(Hostname) +(.*)/\1 ${dirip}/" ~/.ssh/config
diff ~/.ssh/config.bak ~/.ssh/config

echo 'Disabling selinux'
${sshcmd} -o StrictHostKeyChecking=no "sudo setenforce 0; sudo sed -i.bak 's/^\(SELINUX=\).*/\1disabled/' /etc/selinux/config"

echo 'Setting up MariaDB/MySQL, Altus Director and Bind'
${sshcmd} 'sudo yum -y install wget git'
${sshcmd} "wget 'https://raw.githubusercontent.com/gregoryg/macathon-director/master/bin/configure-director-instance.sh'"

${sshcmd} 'bash ./configure-director-instance.sh'

dirhost=`${sshcmd} -o StrictHostKeyChecking=no "hostname -f"`
${sshcmd} "sudo yum -y install nc netcat"

if [ `type -P emacsclient` > /dev/null 2>&1 ] ; then 
    echo Starting proxy
    emacsclient -n /ssh:${SSH_USER}@gcp-director:
else
    echo "Start a proxy with"
    echo "ssh -i ${SSH_PRIVATE_KEYPATH_GCP} ${SSH_USER}@${dirip} -D 8158 -A"
fi

echo waiting for Director to become available
for i in 1 2 3 4 5 6 7 8 9 10
do
    ${sshcmd} 'nc `hostname -f` 7189 < /dev/null'
    ret=$?
    if [ ${ret} == 0 ] ; then
        # echo Opening Director web page
        # open "http://${dirhost}:7189/"
        break
    else
        echo -n .
        sleep 10
    fi
done
echo

echo Cloudera Director URL is http://${dirhost}:7189/
echo "TRAMP URI: //ssh:${SSH_USER}@gcp-director:"
echo 'Done!'
