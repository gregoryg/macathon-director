#!/bin/bash
## Install, configure and start Cloudera Data Science Workbench
## Run as a postCreate script in Cloudera Director 2.4+

set -x
exec > /root/bootstrap-cdsw-post.log 2>&1

# Install and configure CDSW on gateway if not installed
if [ -a "/root/CDSW_GATEWAY_MASTER" ] ;
then
        ## Fix up bridge ethernet that CDSW uses in Kubernetes/Docker
        echo bridge >> /etc/modules-load.d/bridge.conf
        echo br_netfilter >> /etc/modules-load.d/br_netfilter.conf
        modprobe br_netfilter

        # Assure SELinux is disabled
        sed -i.bak -e "s/SELINUX=.*/SELINUX=disabled/" /etc/selinux/config

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


        block_devices=($(awk '/\/data/ {print $1}' /etc/fstab))

        # Unmount /data{n} mounts on the CDSW master, remove from /etc/fstab
        sed -i.bak '/\data/ d' /etc/fstab
        umount /data0
        umount /data1


        # DOCKERDB=${block_devices[0]}
        # APPDB=${block_devices[1]}
        # # DOCKERDB=($(grep '/data0' /etc/fstab | head -1 | cut -d' ' -f1))
        # # APPDB=($(grep '/data1' /etc/fstab | head -1 | cut -d' ' -f1))
        
        # echo "DockerDB partition is ${DOCKERDB} ; Application partition is ${APPDB}"
        # HOSTNAME=`hostname -f`
        IP=$( host -4 `hostname`|sed 's,.\+address ,,')
        DOM="cdsw.${IP:?}.xip.io" # use xip.io for fake wildcard DNS
        # sed -i.bak -e "s/\(MASTER_IP=\).*/\1${IP:?}/" -e "s/\(DOMAIN=\).*/\1${DOM:?}/" -e "s/\(MASTER_HOSTNAME=\).*/\1${HOSTNAME:?}/"  -e "s@\(DOCKER_BLOCK_DEVICES=\).*@\1\"${DOCKERDB:?}\"@" -e "s@\(APPLICATION_BLOCK_DEVICE=\).*@\1\"${APPDB:?}\"@" /etc/cdsw/config/cdsw.conf

        echo 'nameserver 8.8.8.8' | sudo tee -a /etc/resolv.conf # add google DNS to assure xip.io will resolve
        echo "CDSW will run at http://${DOM}:80"


        # Initialize cdsw, hit blank for innumerable warning prompts
        #     cdsw init <<EOF > /root/cdsw-init.log &
        



        # EOF
        echo "Finished cdsw post - run cdsw init manually"
        echo "CDSW will run at http://${DOM}:80"
    else
        # echo "Script not run; non-CDSW gateway or CDSW already installed"
        echo "CDSW already installed - exiting"
    fi
else
    echo "Script not run - non-CDSW gateway"
fi

exit 0
