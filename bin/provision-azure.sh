#!/bin/bash
# TODO: try -E with BSD sed for compatibility
# TODO: create additional resources including vnet,nsg
# TODO: reuse NSG: js-directorNSG

# Edit the defaults below or use environment variables to override
OWNER_TAG=${OWNER_TAG:=${USER}}  # example: jsmith
SSH_USER=${SSH_USER:=${USER}} # examples: gregj/centos/ec2-user
INSTANCE_NAME=${INSTANCE_NAME:=abc-director} # example: js-director
AZ_RESOURCE_GROUP=${AZ_RESOURCE_GROUP:=${USER}-rg} # example: jsmith-rg
SSH_KEYNAME_PUB_AZURE=${SSH_KEYNAME_PUB_AZURE:=abc-azure.pub}
SUBSCRIPTION_NAME=${SUBSCRIPTION_NAME:=Sales Engineering} # or Professional Services

## Do not edit below this line
if [ ! -r ~/.ssh/${SSH_KEYNAME_PUB_AZURE} ] ; then
    echo "Path ~/.ssh/${SSH_KEYNAME_PUB_AZURE} does not exist or cannot be read. - Exiting"
    exit 1
fi
ssh_private_keypath_azure=`echo ${SSH_KEYNAME_PUB_AZURE} | sed 's,\.pub$,,'`

echo """Using the following values
Azure subscription: ${SUBSCRIPTION_NAME}
Owner tag: ${OWNER_TAG}
SSH User: ${SSH_USER}
Azure resource group: ${AZ_RESOURCE_GROUP} (must exist on your Azure axcount)
Instance name: ${INSTANCE_NAME}
SSH public key: ~/.ssh/${SSH_KEYNAME_PUB_AZURE}
SSH private key: ~/.ssh/${ssh_private_keypath_azure}
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
    --name ${INSTANCE_NAME} \
    --tags owner=${OWNER_TAG} \
    --image CentOS \
    --admin-username ${SSH_USER} \
    --ssh-key-value  "`cat ~/.ssh/${SSH_KEYNAME_PUB_AZURE}`")

if [ "$?" != 0 ] ; then
    echo "Error encountered:"
    echo ${dirinfo}
    exit 1
fi
    # --image js-centos74-director26 \

# use jq if available, as it's more reliable parsing JSON
if [ `type -P jq` > /dev/null 2>&1 ] ; then
    dirip=`echo ${dirinfo} | jq -r '.publicIpAddress'`
else
    dirip=`echo ${dirinfo} | grep -P -o  '"publicIpAddress"\s*:\s*"?\K[^,\}"]+'`
fi

sshcmd="ssh -tt -i ~/.ssh/${ssh_private_keypath_azure} ${SSH_USER}@${dirip} "

echo 'Fixing up the .ssh/config file'
# Create a skeleton config if there is none there already
if [ -x $(dirname "$0")/create-ssh-config.sh ] ; then
    $(dirname "$0")/create-ssh-config.sh
fi

sed -i.bak -E "/^ *Host azure-director */,/^ *Host / s/(Hostname) +(.*)/\1 ${dirip}/" ~/.ssh/config
diff ~/.ssh/config.bak ~/.ssh/config

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



# NOTE: Selinux must be disabled or set to permissive to allow DNS to be registered for cluster instances

echo 'Start a proxy with '
echo "ssh -i ~/.ssh/${ssh_private_keypath_azure} ${SSH_USER}@${dirip} -D 8159 -A"
echo "TRAMP URI: /ssh:azure-director:"
echo "Cloudera Director URL: http://${dirshorthost}.cdh-cluster.internal:7189/"


exit 0
