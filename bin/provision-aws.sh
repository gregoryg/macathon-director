#!/bin/bash

# Edit the defaults below or use environment variables to override
# Defaults assume us-east-2 region (Ohio)
# invocation example:
# OWNER_TAG=janesmith \
#   INSTANCE_NAME=js-director \
#   SSH_KEYNAME=janesmith-ohio \
#   SUBNET=subnet-869f6abc \
#   SECURITY_GROUP=sg-abc140a2 \
#   AWS_PROFILE=janesmith \
#   ./provision-aws.sh

OWNER_TAG=${OWNER_TAG:=${USER}}  # example: jsmith
SSH_USER="${SSH_USER:=centos}" # examples: jsmith/centos/ec2-user
INSTANCE_NAME=${INSTANCE_NAME:=abc-director} # example: js-director
REGION=${REGION:=us-east-2} # REPLACE with region 
SSH_KEYNAME=${SSH_KEYNAME:=REPLACE_ME_KEYNAME} # named SSH keypair in your AWS acct (EC2 -> Key Pairs)
SSH_PRIVATE_KEYPATH=${SSH_PRIVATE_KEYPATH:=~/.ssh/${SSH_KEYNAME}.pem}
IMAGE=${IMAGE:=ami-e1496384} # REPLACE with CentOS or RHEL image
SUBNET=${SUBNET:=subnet-xxxxxxxx} # REPLACE with Subnet ID
SECURITY_GROUP=${SECURITY_GROUP:=sg-xxxxxxxx} # REPLACE with Security Group ID
AWS_PROFILE=${AWS_PROFILE:=default}
### Do not edit below this line

aws_prefix="aws --profile ${AWS_PROFILE} --region ${REGION} "

# Launch the Cloudera Director instance
## Cloudera Director with local repo and web server 
echo ${aws_prefix}
echo "Launching the Cloudera Director instance in region ${REGION}"
dirinstanceid=$(${aws_prefix} ec2 run-instances \
    --region ${REGION} \
    --image-id ${IMAGE} \
    --count 1 \
    --instance-type t2.large \
    --associate-public-ip-address \
    --subnet-id ${SUBNET} \
    --key-name ${SSH_KEYNAME} \
    --security-group-ids ${SECURITY_GROUP} \
    --output text \
    --query 'Instances[*].InstanceId')
if [ "$?" != 0 ] ; then
   exit 1
fi

echo 'Waiting to tag instance(s)'
while state=$(${aws_prefix} ec2 describe-instances --instance-ids $dirinstanceid --output text --query 'Reservations[*].Instances[*].State.Name'); test "$state" = "pending"; do
  sleep 10; echo -n '.'
done; echo " $state"

## Tag the Director instance
${aws_prefix} ec2 create-tags \
    --resources $dirinstanceid \
    --tags Key=owner,Value=${OWNER_TAG} Key=Name,Value=greg-director

# while state=$(${aws_prefix} ec2 describe-instances --region us-west-1 --instance-ids $dbinstanceid --output text --query 'Reservations[*].Instances[*].State.Name'); test "$state" = "pending"; do
#   sleep 10; echo -n '.'
# done; echo " $state"

# ## Tag the DB instance
# ${aws_prefix} ec2 create-tags \
#     --region us-west-1 \
#     --resources $dbinstanceid \
#     --tags Key=owner,Value=gregoryg Key=Name,Value=greg-mysql

echo 'Fixing up the .ssh/config file'
info=$(${aws_prefix} ec2 describe-instances --instance-ids ${dirinstanceid} --query 'Reservations[*].Instances[*].{pubip:PublicIpAddress,privateip:PrivateIpAddress,privatedns:PrivateDnsName}' --output json)

dirip=`echo ${info} | grep -P -o '"pubip"\s*:\s*"\K[^"]+'`
# privip=`echo ${info} | grep -P -o '"privateip"\s*:\s*"\K[^"]+'`
dirfqdn=`echo ${info} | grep -P -o '"privatedns"\s*:\s*"\K[^"]+'`

sshcmd="ssh -tt -i ${SSH_PRIVATE_KEYPATH} ${SSH_USER}@${dirip} "
# dirip=`echo $info | jq -r '.[0][0].pubip'`
# privip=`echo $info | jq -r '.[0][0].privateip'`
# dirfqdn=`echo $info | jq -r '.[0][0].privatedns'`
ssh-keygen -q -R ${dirip}

# # echo 'Fixing up the .ssh/config file'
# sed -i.bak -e "/^ *Host aws-director/,/^ *Host /{s/^\( *Hostname *\)\(.*\)/\1$dirip/}" ~/.ssh/config
# diff ~/.ssh/config ~/.ssh/config.bak

echo 'Disabling selinux'
${sshcmd} -o StrictHostKeyChecking=no "sudo setenforce 0; sudo sed -i.bak 's/^\(SELINUX=\).*/\1disabled/' /etc/selinux/config"

echo 'Setting up MariaDB/MySQL, Altus Director and Bind'
${sshcmd} 'sudo yum -y install wget git'
${sshcmd} "wget 'https://raw.githubusercontent.com/gregoryg/macathon-director/master/bin/configure-director-instance.sh'"

${sshcmd} 'bash ./configure-director-instance.sh'


${aws_prefix} ec2 wait system-status-ok --instance-ids ${dirinstanceid}
if [ `type -P emacsclient` > /dev/null 2>&1 ] ; then 
    emacsclient -n /ssh:${SSH_USER}@${dirip}:
else
    echo "Start a proxy with"
    echo "ssh -i ${SSH_PRIVATE_KEYPATH} ${SSH_USER}@${dirip} -D 8157 -A"
fi

${sshcmd} 'sudo yum -y install nc netcat'
echo waiting for Director to become available
for i in 1 2 3 4 5 6 7 8 9 10
do
    ${sshcmd} "nc localhost 7189 < /dev/null"
    ret=$?
    if [ ${ret} == 0 ] ; then
        # echo Opening Director web page
        # open "http://${dirfqdn}:7189/"
        break
    else
        echo -n .
        sleep 10
    fi
done
echo

echo "Cloudera Altus Director URL: http://${dirfqdn}:7189/"
echo "TRAMP URI: //ssh:${SSH_USER}@aws-director:"

echo 'Done!'
