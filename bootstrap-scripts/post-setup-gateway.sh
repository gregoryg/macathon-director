#!/bin/bash
# [[file:~/projects/cdh-projects/ingest.org::*Set%20up%20basics%20of%20environment][Set up basics of environment:1]]
USER='gregj'
# This script can run as a Cloudera Altus Director post-cluster installation step
# This script sets up the gateway/edge node for shell usage
# It is expected to run as a post-installation script in Cloudera Altus Director

. ./setup-analytics.inc
. ./setup-cowsay.sh

function gateway_status() {
    # Status of this node as gateway/edge
    # zero is true, non-zero false
    test -f "/root/GATEWAY_NODE"
# `hostname -s | grep '\-gw\-'
}

 function install_prereqs() {
     sudo yum -y install epel-release
     sudo yum -y install python-pip wget curl telnet finger mlocate jq htop net-tools git mysql-connector-java

     echo "Setting up HDFS home data dir for user ${USER}"
     sudo -u hdfs hdfs dfs -mkdir -p /user/${USER}/data
     sudo -u hdfs hdfs dfs -chown -R ${USER} /user/${USER}
 }
 
 function set_environment() {
     # if running as a Director post-creation script, these variables will be set:
     # CM_USERNAME, CM_PASSWORD, DEPLOYMENT_HOST_PORT, CLUSTERNAME
     # if they are not set, try to discover the values or use reasonable defaults
     if [ -v CM_USERNAME ] ; then
         cm_username=${CM_USERNAME}
         cm_password=${CM_PASSWORD}
         clustername=${CLUSTERNAME}
         cm_host_port=${DEPLOYMENT_HOST_PORT}
     else
         ## we're on our own, let's find out where CM is running
         if [ -f /etc/cloudera-scm-agent/config.ini ] ; then
             cmhost=`grep server_host= /etc/cloudera-scm-agent/config.ini | cut -d'=' -f2`
             cmport=7180
             # cmport=`grep server_port= /etc/cloudera-scm-agent/config.ini | cut -d'=' -f2`
             cm_host_port=${cmhost}:${cmport}
         else
             echo "Error: Cannot determine Cloudera Manager host address - does this host run Cloudera Manager Agent?"
             exit 1
         fi
         # CM User and pass must be defaulted 
         cm_username=admin
         cm_password=admin
         # get cluster name
         clustername=$(curl --silent -X GET -u ${cm_username}:${cm_password} http://${cm_host_port}/api/v14/clusters | jq -r '.items[].name')
         if [ "$?" -ne 0 ] ; then
             echo "Error: could not use CM API for user ${cm_username} at ${cm_host_port} - exiting"
             exit 1
         fi
         if [ 1 != `echo $clustername | wc -l` ] ; then
             echo "Error: I can only deal with 1 cluster managed by the CM - found: `echo $clustername`"
             exit 1
         fi
     fi
 } # function set_environment

 
 if [ $(gateway_status) -ne 0 ] ; then
     echo "Not a gateway/edge node - nothing to do"
     exit 0
 fi
 
 install_prereqs
 set_environment
 setup_analytics
 # setup_cowsay
 echo Cloudera Manager is running on ${cm_host_port}
 exit 0


