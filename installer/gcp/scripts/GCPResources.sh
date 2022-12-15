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


if [ "$#" -ne 1 ]; then
    ERROR "Pass the GCP username or value to search for in resources";
    exit
fi

MyUser=$1
INFO "Searching for data containing: $MyUser"
echo ""

INFO "Listing Compute Instances"
LINE "=================================="
gcloud compute instances list | grep $MyUser
echo ""

INFO "Listing Compute Instance Groups"
LINE "=================================="
gcloud compute instance-groups list | grep $MyUser
echo ""

INFO "Listing Compute Disks"
LINE "=================================="
gcloud compute disks list | grep $MyUser
echo ""

INFO "Listing Compute Networks"
LINE "=================================="
gcloud compute networks list | grep $MyUser
echo ""

INFO "Listing Compute Networks Subnets"
LINE "=================================="
gcloud compute networks subnets list | grep $MyUser
echo ""

INFO "Listing Compute Routers"
LINE "=================================="
gcloud compute routers list | grep $MyUser
echo ""

INFO "Listing Compute Firewal Rules"
LINE "=================================="
gcloud compute firewall-rules list | grep $MyUser
echo ""

INFO "Listing Compute Health Checks"
LINE "=================================="
gcloud compute health-checks list | grep $MyUser
echo ""

INFO "Listing Compute HTTP Health Checks"
LINE "=================================="
gcloud compute http-health-checks list | grep $MyUser
echo ""

INFO "Listing Compute Forwarding Rules"
LINE "=================================="
gcloud compute forwarding-rules list | grep $MyUser
echo ""

INFO "Listing Compute Addresses"
LINE "=================================="
gcloud compute addresses list | grep $MyUser
echo ""

INFO "Listing Compute Target Pools"
LINE "=================================="
gcloud compute target-pools list | grep $MyUser
echo ""

INFO "Listing Compute Backend Services"
LINE "=================================="
gcloud compute backend-services list | grep $MyUser
echo ""

INFO "Listing DNS Managed Zones"
LINE "=================================="
gcloud dns managed-zones list | grep $MyUser
echo ""

INFO "Listing Service Accounts"
LINE "=================================="
gcloud iam service-accounts list | grep $MyUser
echo ""

INFO "Listing Compute Images"
LINE "=================================="
gcloud compute images list | grep $MyUser
echo ""

INFO "GSUtil"
LINE "=================================="
gsutil ls | grep $MyUser
echo ""

INFO "Listing Deployments"
LINE "=================================="
gcloud deployment-manager deployments list | grep $MyUser
echo ""
