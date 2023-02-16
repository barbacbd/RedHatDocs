#!/bin/bash

COLOR_OFF='\033[0m'
BLUE='\033[0;34m'

function INFO() {
    echo -e "${BLUE}${1}${COLOR_OFF}"
}

function CopyMachineSets () {

    if [ -d "assets" ]; then
	INFO "Changing dir to assets ...";
	cd assets;
    fi
    
    TempFile=/tmp/ms1.yaml
    MachineCopyName="hello-world"
    SearchText="${USER}"
    
    # This script is intended be used to copy a machineset with a new name
    # where the name does not contain the INFRA-ID or the cluster name
    
    # This script is expected to be run from the same location where
    # openshift-install is executed or where the `dir` variable is set
    INFO "exporting KUBECONFIG ..."
    export KUBECONFIG=auth/kubeconfig
    
    # sanity check print the nodes
    INFO "Printing Nodes ..."
    oc get nodes
    
    # Get the name of a machine in the machinesets that we want to copy
    # This will just take the first name in the list
    MachineName=$(oc get machinesets -n openshift-machine-api | grep $SearchText | awk 'NR==1{print $1}')
    INFO "Using machineset $MachineName ..."
    
    # Get the configuration of the machine and save it to a file
    INFO "Copying $MachineName to $TempFile ..."
    oc get machinesets $MachineName -n openshift-machine-api -oyaml > $TempFile
    
    # replace the instances of the machineset name in the file
    # with the fake/new machine name
    INFO "Replacing $MachineName with $MachineCopyName ..."
    sed -i "s/$MachineName/$MachineCopyName/g" $TempFile
    
    # Remove the status from the file
    INFO "Removing \"status\" from $TempFile ..."
    python3 -c '\
import yaml;   
import sys;    
path = sys.argv[1];
data = yaml.safe_load(open(path))
if "status" in data:	
    del data["status"]	
open(path, "w").write(yaml.dump(data, default_flow_style=False))' $TempFile

    # Create the new machine
    INFO "Creating the machineset from $TempFile ..."
    oc create -f $TempFile

    # print the list of machinesets. We should see our new one
    MachineStatus=$(oc get machines -n openshift-machine-api | grep $MachineCopyName  | awk 'NR==1{print $2}')
    
    while [[ "$MachineStatus" != "Running" ]] ; do
	INFO "$MachineCopyName status: $MachineStatus"
	sleep 10
	TempMachineStatus=$(oc get machines -n openshift-machine-api | grep $MachineCopyName  | awk 'NR==1{print $2}')
	
	if [[ "$TempMachineStatus" != "$MachineStatus" ]]; then
	    INFO "$MachineCopyName has changed to $TempMachineStatus"
	    MachineStatus=$TempMachineStatus
	fi
    done

    INFO "Listing status of all machines ..."
    oc get machines -n openshift-machine-api
    
    INFO "Removing $TempFile ..."
    rm $TempFile
}

if [ -f "Install.sh" ] ; then
    INFO "Executing Install.sh ...";
    ./Install.sh
fi

INFO "Executing CopyMachineSets ...";
CopyMachineSets
