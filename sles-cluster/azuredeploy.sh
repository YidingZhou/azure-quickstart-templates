#!/bin/sh

# This script can be found on https://raw.githubusercontent.com/YidingZhou/azure-quickstart-templates/SLES/sles-cluster/azuredeploy.sh
# This script is part of azure deploy ARM template
# This script assumes the Linux distribution to be Ubuntu (or at least have apt-get support)

# Basic info
date > /tmp/azuredeploy.log.$$ 2>&1
whoami >> /tmp/azuredeploy.log.$$ 2>&1
echo $@ >> /tmp/azuredeploy.log.$$ 2>&1
env >> /tmp/azuredeploy.log.$$ 2>&1

# Usage
if [ "$#" -ne 9 ]; then
  echo "Usage: $0 MASTER_NAME MASTER_IP WORKER_NAME WORKER_IP_BASE WORKER_IP_START NUM_OF_VM ADMIN_USERNAME ADMIN_PASSWORD TEMPLATE_BASE" >> /tmp/azuredeploy.log.$$
  exit 1
fi

# Preparation steps - hosts and ssh
###################################

# Parameters
MASTER_NAME=$1
MASTER_IP=$2
WORKER_NAME=$3
WORKER_IP_BASE=$4
WORKER_IP_START=$5
NUM_OF_VM=$6
ADMIN_USERNAME=$7
ADMIN_PASSWORD=$8
TEMPLATE_BASE=$9

# Update master node
echo $MASTER_IP $MASTER_NAME >> /etc/hosts
echo $MASTER_IP $MASTER_NAME > /tmp/hosts.$$

# Update ssh config file to ignore unknow host
# Note all settings are for azureuser, NOT root
sudo -u $ADMIN_USERNAME sh -c "mkdir /home/$ADMIN_USERNAME/.ssh/;echo Host master worker\* > /home/$ADMIN_USERNAME/.ssh/config; echo StrictHostKeyChecking no >> /home/$ADMIN_USERNAME/.ssh/config; echo UserKnownHostsFile=/dev/null >> /home/$ADMIN_USERNAME/.ssh/config"

# Generate a set of sshkey under /honme/azureuser/.ssh if there is not one yet
if ! [ -f /home/$ADMIN_USERNAME/.ssh/id_rsa ]; then
    sudo -u $ADMIN_USERNAME sh -c "ssh-keygen -f /home/$ADMIN_USERNAME/.ssh/id_rsa -t rsa -N ''"
    sudo -u $ADMIN_USERNAME sh -c "cp /home/$ADMIN_USERNAME/.ssh/id_rsa.pub /home/$ADMIN_USERNAME/.ssh/authorized_keys"
fi

# Install sshpass to automate ssh-copy-id action
zypper --quiet --non-interactive addrepo http://download.opensuse.org/repositories/home:Strahlex/SLE_12/home:Strahlex.repo
zypper --quiet --non-interactive --gpg-auto-import-keys install sshpass

# Loop through all worker nodes, update hosts file and copy ssh public key to it
# The script make the assumption that the node is called %WORKER+<index> and have
# static IP in sequence order
i=0
while [ $i -lt $NUM_OF_VM ]
do
   workerip=`expr $i + $WORKER_IP_START`
   echo 'I update host - '$WORKER_NAME$i >> /tmp/azuredeploy.log.$$ 2>&1
   echo $WORKER_IP_BASE$workerip $WORKER_NAME$i >> /etc/hosts
   echo $WORKER_IP_BASE$workerip $WORKER_NAME$i >> /tmp/hosts.$$
   sudo -u $ADMIN_USERNAME sh -c "sshpass -p '$ADMIN_PASSWORD' ssh-copy-id $WORKER_NAME$i"

   worker=$WORKER_NAME$i
   echo "SCP to $worker"  >> /tmp/azuredeploy.log.$$ 2>&1 
   sudo -u $ADMIN_USERNAME scp /home/$ADMIN_USERNAME/.ssh/config $ADMIN_USERNAME@$worker:/home/$ADMIN_USERNAME/.ssh/config >> /tmp/azuredeploy.log.$$ 2>&1
   sudo -u $ADMIN_USERNAME scp /home/$ADMIN_USERNAME/.ssh/id_rsa $ADMIN_USERNAME@$worker:/home/$ADMIN_USERNAME/.ssh/id_rsa >> /tmp/azuredeploy.log.$$ 2>&1

   i=`expr $i + 1`
done

exit 0
