#!/bin/bash

# This script is used to cleanup the RHEL node workers after an openshift ansible
# installation. The rhel worker nodes are created with openshift ansible (specifically
# this was created while using oi-dev). The RHCOS workers (do NOT have rhel in the name)
# are created by openshift-installer, and that program has its own destroy implementation
# for the resources that it created. 

COLOR_OFF='\033[0m'
RED='\033[0;31m' # ERROR
YELLOW='\033[0;33m' # WARNING
GREEN='\033[0;32m' # DEBUG
BLUE='\033[0;34m'  # INFO

function ERROR() {
    echo -e "${RED}[${FUNCNAME[0]}]: ${1}${COLOR_OFF}"
}

function WARN() {
    echo -e "${YELLOW}[${FUNCNAME[0]}]: ${1}${COLOR_OFF}"
}

function DEBUG() {
    echo -e "${GREEN}[${FUNCNAME[0]}]: ${1}${COLOR_OFF}"
}

function INFO() {
    echo -e "${BLUE}[${FUNCNAME[0]}]: ${1}${COLOR_OFF}"
}


# Try the oc commands, if we cannot run oc commands, fail early
output=$(oc get machinesets -A);

if [ $? -ne 0 ] ; then
    ERROR "oc command failed, please check that KUBECONFIG is exported.";
    exit
fi

rhelMachines=$(oc get machinesets -A | grep "rhel")

# Remove the machinesets individually.
# This does not combine the machineset names or the namespaces in the event that
# the namespaces change in the future or there are multiple namespaces
while IFS= read -r line; do
    INFO "Deleting $(echo $line | head -n1 | awk '{ print $1 }')"
    $(oc delete machinesets $(echo $line | head -n1 | awk '{ print $2 }') -n $(echo $line | head -n1 | awk '{ print $1 }'))
done <<< "$rhelMachines"

# wait for the machines to be deleted
while true
do
    machinesDeleting=$(oc get machines -A | grep "deleting");

    if [ -z "$machinesDeleting" ]; then
	INFO "Machines have been cleaned up.";
	break
    fi

    # this process usually takes 1-2 minutes. 
    DEBUG "Machines are still being cleaned up ..."
    sleep 5
done

# find and delete the bastion "service" 
findBastion=$(oc get service -n test-ssh-bastion)
if [ ! -z "$findBastion" ]; then
    $(oc delete service -n test-ssh-bastion)

    if [ $? -eq 0 ]; then
	INFO "Deleted bastion."
    else
	WARN "Failed to delete bastion ..."
    fi
fi
