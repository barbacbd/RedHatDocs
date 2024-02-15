#!/bin/bash

# Script to find all GCP resources related to the user.
# The output will NOT attempt to destroy or create
# resources; all resources are listed. 

COLOR_OFF='\033[0m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'

function ERROR() {
    echo -e "${RED}[${FUNCNAME[0]}]: ${1}${COLOR_OFF}"
}

function LINE() {
    echo -e "${YELLOW}${1}${COLOR_OFF}"
}

function INFO() {
    echo -e "${BLUE}${1}${COLOR_OFF}"
}


if [ ! -f "metadata.json" ]; then
    ERROR "Failed to find metadata.json"
    exit
fi

infraID=`jq -r '.infraID' metadata.json`

INFO "Attempting to destroy any cluster-api-provider-gcp process"
output=`ps aux | grep cluster-api-provider-gcp | awk '{print $2}'`
for out in $output; do
    sudo kill -9 $out
done

INFO "Deleting firewall rules"
output=`gcloud compute firewall-rules list --uri | grep $infraID`
for out in $output; do
   yes | gcloud compute firewall-rules delete $output
done

INFO "Deleting forwarding rules"
output=`gcloud compute forwarding-rules list --uri | grep $infraID`
for out in $output; do
   yes | gcloud compute forwarding-rules delete $output
done

INFO "Deleting target tcp proxies"
output=`gcloud compute target-tcp-proxies list --uri | grep $infraID`
for out in $output; do
   yes | gcloud compute target-tcp-proxies delete $output
done

INFO "Deleting backend services"
output=`gcloud compute backend-services list --uri | grep $infraID`
for out in $output; do
   yes | gcloud compute backend-services delete $output
done

INFO "Deleting health checks"
output=`gcloud compute health-checks list --uri | grep $infraID`
for out in $output; do
   yes | gcloud compute health-checks delete $output
done

INFO "Deleting http health checks"
output=`gcloud compute http-health-checks list --uri | grep $infraID`
for out in $output; do
   yes | gcloud compute https-health-checks delete $output
done

INFO "Deleting routers"
output=`gcloud compute routers list --uri | grep $infraID`
for out in $output; do
   yes | gcloud compute routers delete $output
done

masterSubnet="$infraID-master-subnet"
INFO "Deleting master subnet"
output=`gcloud compute networks subnets list | grep $masterSubnet`
for out in $output; do
   yes | gcloud compute networks subnets delete $output
done

workerSubnet="$infraID-worker-subnet"
INFO "Deleting worker subnet"
output=`gcloud compute networks subnets list | grep $workerSubnet`
for out in $output; do
   yes | gcloud compute networks subnets delete $output
done

INFO "Deleting networks"
# this will delete the subnets associated with the network as CAPI created these automatically
output=`gcloud compute networks list --uri | grep $infraID`
for out in $output; do
   yes | gcloud compute networks delete $output
done

INFO "Deleting compute addresses"
output=`gcloud compute addresses list --uri | grep $infraID`
for out in $output; do
   yes | gcloud compute addresses delete $output
done

INFO "Deleting instance groups"
output=`gcloud compute instance-groups list --uri | grep $infraID`
for out in $output; do
   yes | gcloud compute instance-groups managed delete $output
done
