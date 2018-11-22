#!/bin/bash
# TODO: try -E with BSD sed for compatibility
# TODO: create additional resources including vnet,nsg
# TODO: reuse NSG: js-directorNSG

# Edit the defaults below or use environment variables to override
OWNER_TAG=${OWNER_TAG:=${USER}}  # example: jsmith
SSH_USERNAME=${SSH_USERNAME:=${USER}} # example: gregj/centos/ec2-user
AZ_RESOURCE_GROUP=${AZ_RESOURCE_GROUP:=${USER}-rg} # example: jsmith-rg
AZ_INSTANCE_NAME=${AZ_INSTANCE_NAME:=abc-director} # example: js-director
SSH_KEYNAME=${SSH_KEYNAME:=abc-azure.pub}
SUBSCRIPTION_NAME=${SUBSCRIPTION_NAME:=Sales Engineering} # or Professional Services

if [ ! -r ~/.ssh/${SSH_KEYNAME} ] ; then
    echo "Path ~/.ssh/${SSH_KEYNAME} does not exist or cannot be read. - Exiting"
    exit 1
fi

echo """Using the following values
Azure subscription: ${SUBSCRIPTION_NAME}
Owner tag: ${OWNER_TAG}
SSH User: ${SSH_USERNAME}
Azure resource group: ${AZ_RESOURCE_GROUP} (must exist on your Azure axcount)
Instance name: ${AZ_INSTANCE_NAME}
SSH public key: ~/.ssh/${SSH_KEYNAME}
"""
read -p  "Proceed? [Y/n]: " -n 1 -r
# echo

if [[ ! $REPLY =~ ^[Yy]$ ]] ; then
    echo Set the environment variables you require, then run this script again - exiting
    exit 1
fi


echo 'Create resource group if it does not exist'
az group create --location westus --tags owner=${OWNER_TAG} --name ${AZ_RESOURCE_GROUP} >/dev/null

if [ "$?" -ne 0 ] ; then
    exit 1
fi

az account set --subscription "${SUBSCRIPTION_NAME}"

if [ "$?" != 0 ] ; then
   exit
fi

echo 'Starting provisioning of instance on Azure - please use default DNS for your VNET!'
# 1) Launch combined Director/MariaDB instance
dirinfo=$(az vm create \
    --size STANDARD_DS13_V2 \
    --resource-group ${AZ_RESOURCE_GROUP} \
    --name ${AZ_INSTANCE_NAME} \
    --tags owner=${OWNER_TAG} \
    --image CentOS \
    --admin-username ${SSH_USERNAME} \
    --ssh-key-value  "`cat ~/.ssh/${SSH_KEYNAME}`")

if [ "$?" != 0 ] ; then
    echo "Error encountered:"
    echo ${dirinfo}
    exit 1
fi
    # --image js-centos74-director26 \

# if [ -x $(dirname "$0")/create-ssh-config.sh ] ; then
#     $(dirname "$0")/create-ssh-config.sh
# fi

# use jq if available, as it's more reliable parsing JSON
if [ type -P jq > /dev/null 2>&1 ] ; then
    dirip=`echo ${dirinfo} | jq -r '.publicIpAddress'`
else
    dirip=`echo ${dirinfo} | grep -P -o  '"publicIpAddress"\s*:\s*"?\K[^,\}"]+'`
fi

sshcmd="ssh -tt -i ~/.ssh/${SSH_KEYNAME} ${SSH_USERNAME}@${dirip} "

# echo 'Fixing up the .ssh/config file'
# gsed -i.bak "/^ *Host azure-director */,/^ *Host /{s/^\( *Hostname *\)\(.*\)/\1$dirip/}" ~/.ssh/config
# diff ~/.ssh/config.bak ~/.ssh/config

echo 'Disabling selinux'
${sshcmd} -o StrictHostKeyChecking=no "sudo setenforce 0; sudo sed -i.bak 's/^\(SELINUX=\).*/\1disabled/' /etc/selinux/config"


echo 'Assuring instance can resolve internet DHCP - in case DNS is still set to custom'
${sshcmd} "echo 'nameserver 8.8.8.8' | sudo tee -a /etc/resolve.conf"

echo 'Setting up MariaDB/MySQL, Altus Director and Bind'

dirhost=`${sshcmd} "hostname -f"`
dirshorthost=`${sshcmd} "hostname -s"`
${sshcmd} 'sudo yum -y install wget git'

echo 'Placing director-scripts on instance - use DNS scripts on Azure'
${sshcmd} "git clone 'https://github.com/cloudera/director-scripts.git'"
${sshcmd} "wget 'https://raw.githubusercontent.com/gregoryg/macathon-director/master/bin/configure-director-instance.sh'"


${sshcmd} 'bash ./configure-director-instance.sh'

echo 'Now please set DNS - set internal domain to cdh-cluster.internal'
${sshcmd} 'sudo hostname `hostname -s`.cdh-cluster.internal'
${sshcmd} 'sudo bash ./director-scripts/azure-dns-scripts/bind-dns-setup.sh'
${sshcmd} 'sudo service named restart; sudo bash ./director-scripts/azure-dns-scripts/dns-test.sh'


# echo Starting proxy
# emacsclient -n '/ssh:${SSH_USERNAME}@azure-director:'
# echo waiting for Director to become available
# sleep 30
# for i in 1 2 3 4 5 6 7 8 9 10
# do
#     ${sshcmd} 'nc `hostname` 7189 < /dev/null'
#     ret=$?
#     if [ ${ret} == 0 ] ; then
#         # echo Opening Director web page
#         # open "http://${dirhost}:7189/"
#         break
#     else
#         echo -n .
#         sleep 10
#     fi
# done

# NOTE: Selinux must be disabled or set to permissive to allow DNS to be registered for cluster instances

echo 'Start a proxy with '
echo "ssh -i ~/.ssh/${SSH_KEYNAME} ${SSH_USERNAME}@${dirip} -D 8159 -A"
echo "TRAMP URI: /ssh:azure-director:"
echo "Cloudera Director URL: http://${dirshorthost}.cdh-cluster.internal:7189/"


exit 0
