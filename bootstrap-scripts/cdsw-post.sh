#!/bin/bash
## Install, configure and start Cloudera Data Science Workbench
## Run as a postCreate script in Cloudera Director 2.4+

set -x
exec > /root/bootstrap-cdsw-post.log 2>&1

# Install and configure CDSW on gateway if not installed
if ! [ -a "/root/CDSW_GATEWAY_MASTER" ] 
then
    echo "Script not run - non-CDSW gateway"
    exit 0
fi

yum -y install jq

if ! [ `type -P jq` > /dev/null 2>&1 ] ; then
    echo Could not find jq command - exiting with error
    exit 1
fi

# ## Fix up bridge ethernet that CDSW uses in Kubernetes/Docker
# echo bridge >> /etc/modules-load.d/bridge.conf
# echo br_netfilter >> /etc/modules-load.d/br_netfilter.conf
# modprobe br_netfilter

# Assure SELinux is disabled
sed -i.bak -e "s/SELINUX=.*/SELINUX=disabled/" /etc/selinux/config
setenforce 0

# renable ip6 and iptables after director disabled them
sed -i "/net.ipv6.conf.all.disable_ipv6/d" /etc/sysctl.conf
sed -i "/net.ipv6.conf.default.disable_ipv6/d" /etc/sysctl.conf
echo "net.ipv6.conf.all.disable_ipv6=0" >> /etc/sysctl.conf
echo "net.ipv6.conf.default.disable_ipv6=0" >> /etc/sysctl.conf
echo "net.bridge.bridge-nf-call-iptables=1" >> /etc/sysctl.conf
sysctl -p

systemctl enable iptables
systemctl restart iptables
systemctl enable rpcbind
systemctl restart rpcbind
systemctl restart rpc-statd


# Use directive mountAllUnmountedDisks=false in instance group normalizationConfig
# block_devices=($(awk '/\/data/ {print $1}' /etc/fstab))

# # Unmount /data{n} mounts on the CDSW master, remove from /etc/fstab
# sed -i.bak '/\data/ d' /etc/fstab
# umount /data0
# umount /data1


ip=$(ip -4 route get 1 | head -1 | sed 's,^.\+src \+\([\.0-9]\+\).*,\1,')
# Use nip.io for wildcard DNS
domain="cdsw.${ip}.nip.io"

serviceName=$(curl -u $CM_USERNAME:$CM_PASSWORD -X GET http://$DEPLOYMENT_HOST_PORT/api/v18/clusters/$CLUSTER_NAME/services  | jq -r '.items[] | select(.type == "CDSW") .name')

config=$(curl -H "Content-Type: application/json" -u $CM_USERNAME:$CM_PASSWORD -X PUT -d '{"items": [{"name": "cdsw.domain.config", "value":"'${domain}'"},{"name":"cdsw.master.ip.config","value":"'${ip}'"}]}' http://${DEPLOYMENT_HOST_PORT}/api/v18/clusters/${CLUSTER_NAME}/services/${serviceName}/config )


# Restart the service to apply changes
curl -u $CM_USERNAME:$CM_PASSWORD -X POST http://$DEPLOYMENT_HOST_PORT/api/v18/clusters/${CLUSTER_NAME}/services/${serviceName}/commands/restart

echo 'nameserver 8.8.8.8' | tee -a /etc/resolv.conf # add google DNS to assure xip.io will resolve
echo "CDSW will run at http://${domain}:80"

exit 0
