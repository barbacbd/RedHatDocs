#!/bin/bash

# Background: The openshift installer team was running into quota/resource issues.
# If there are more than 50 VPCs created at a time, then the quota is reached. The
# quota could be increased, but this could be an issue if we are leaking resources
# in CI. This script is used to find and destroy CI VPCs that are older than X days.
#
# The entire script is dependent upon finding out of date VPCs that match the
# ci-op format that we expect. Then we need to delete all of the dependent resources.
#
# Note: this will use the gcloud account that is logged in. The default project
# and region will be used. Please set this information if you would like to change
# the behavior of this script.

OutOfDateVPCs=()

VPCs=$(gcloud compute networks list | awk '{print $1}')
for i in $VPCs
do
    # Note this will also identify any cluster VPC resource
    # that begins with "ci-op-"
    if [[ $i == ci-op-* ]]; then
        vpcdate=$(gcloud compute networks describe  $i | head -2 | tail -1 | awk '{print $2}')
        removed=$(echo $vpcdate | tr -d "'")
        ctime=`date +%s`

        ftime=$(date -j -f "%Y-%m-%dT%H:%M:%S" $removed +%s)

        # The 6 hour time difference of 21600 seconds should work
        # this is currently a 10 hour time difference
        diff=$(( (ctime - ftime) ))

        #DiffDays=$(( (ctime - ftime) / 86400))
        #DiffHours=$(( (ctime - ftime) / 3600))
        #echo "${i} -> ${DiffDays}, ${DiffHours}"

        if [ $diff -ge "36000" ]; then
            OutOfDateVPCs+=($i)
        fi
    fi
done 

# Delete all firewall rules associated with the networks/vpcs to be deleted.
gcloud compute firewall-rules list | tail -n+2 | awk '{print $1" "$2}' | \
while read -r FirewallRuleName VPCName; do
    
    if [[ " ${OutOfDateVPCs[*]} " =~ [[:space:]]${VPCName}[[:space:]] ]]; 
    then
        echo "${FirewallRuleName} - ${VPCName}"
        yes | gcloud compute firewall-rules delete "${FirewallRuleName}"
    fi

done

# Delete all of the routers and nat router resources.
# The resources are compared to the list of VPCs to be deleted.
gcloud compute routers list | tail -n+2 | awk '{print $1" "$2" "$3}' | \
while read -r RouterName RouterRegion VPCName; do

    if [[ " ${OutOfDateVPCs[*]} " =~ [[:space:]]${VPCName}[[:space:]] ]]; then
        NatRouterName=$(gcloud compute routers nats list --router="$RouterName" --region="$RouterRegion" | tail -n+2 | awk '{print $1}')
        yes | gcloud compute routers nats delete "$NatRouterName" --router="$RouterName" --region="$RouterRegion"

        # Delete the routers
        yes | gcloud compute routers delete "${RouerName}" --region "${RouterRegion}"
    fi

done

# The networks have been identified, now the subnetworks associated with the
# networks need to be removed (first). If we do not deleted the subnetworks
# then the VPC deletions will fail.
for i in "${OutOfDateVPCs[@]}"
do
    gcloud compute networks subnets list --network "${i}" | tail -n+2 | awk '{print $1" "$2}' | \
    while read -r SubnetName SubnetRegion; do
        yes | gcloud compute networks subnets delete "${SubnetName}" --region "${SubnetRegion}"
    done
done

for i in "${OutOfDateVPCs[@]}"
do
    yes | gcloud compute networks delete $i
done