#!/bin/bash
# #########################################################
# NAME: fleetset.sh
# DESC: Setup local environment for using 'fleetctl' and API.
# LOG:
# yyyy/mm/dd [user]: [version][notes]
# 2015/02/25 cgwong: v0.1.0 Creation
# #########################################################

# Process command line argument (vagrant box name)
if [ $# -ne 1 ]; then
  echo "[$(date +'%Y-%m-%d %T')]: ERROR - Name of vagrant host required."
  exit 1
else
  vbox=$1
fi

# Add Vagrant private keys to ssh agent
echo "[$(date +'%Y-%m-%d %T')]: INFO - Adding SSH keys from Vagrant host ${vbox} to ssh agent."
vagrant ssh-config ${vbox} | sed -n "s/IdentityFile//gp" | xargs ssh-add

# Detect IP from Vagrant environment and set FLEETCTL variables
echo "[$(date +'%Y-%m-%d %T')]: INFO - Updating FLEETCTL_TUNNEL with Vagrant host ${vbox} SSH port."
FLEETCTL_TUNNEL="$(vagrant ssh-config ${vbox} | sed -n "s/[ ]*HostName[ ]*//gp"):$(vagrant ssh-config ${vbox} | sed -n "s/[ ]*Port[ ]*//gp")" ; export FLEETCTL_TUNNEL
echo "[$(date +'%Y-%m-%d %T')]: INFO - FLEETCTL_TUNNEL=${FLEETCTL_TUNNEL}"

