#!/bin/bash
# This script prepares a CDSW master node
# Wildcard DNS for the CDSW will be provided by the 'gg-director' instance
# DNS on gg-director must point to the CDSW master prior to CM installing CDSW

touch /root/CDSW_GATEWAY_MASTER
echo ${dnsip} > /root/CDSW_GATEWAY_MASTER

umount /data0 /data1
sed -i.bak '/\/data[01]/ s/^/# /g' /etc/fstab 

directorip=`dig +short gg-director.c.gcp-se.internal` 2>/dev/null

if [ -z ${directorip} ] ; then
    echo 'Warning: cannot get IP Address for the gg-director instance - CDSW start will fail'
    exit 0
fi

# Update dnsmasq on the gg-director instance with our IP address for *.cdsw.gregj.internal
# echo "address=/.cdsw.gregj.internal/${directorip}" | ssh -t -t gregj@${directorip} "cat - | sudo tee /etc/dnsmasq.d/cdsw-gregj.conf ; sudo service dnsmasq restart"

# Disable NetworkManager DNS and replace resolv.conf to use our wildcard CDSW DNS
echo "[main]
dns=none" | sudo tee /etc/NetworkManager/conf.d/no-dns.conf
sudo systemctl restart NetworkManager.service

echo "search c.gcp-se.internal google.internal
nameserver ${directorip}
nameserver 169.254.169.254" | sudo tee /etc/resolv.conf
#    ssh -t -t gregj@${directorip} "cat - | sudo tee /etc/resolv.conf"

exit 0
