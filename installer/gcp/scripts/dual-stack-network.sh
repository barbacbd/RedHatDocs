#!/bin/bash

NAME=`whoami`
DATE=`date +"%Y%m%d"`
PROJECT_ACCOUNT="${NAME}@redhat.com"
PROJECT_ID=`gcloud config list project | awk 'NR==2{print $3; exit}'`

# Read the destroy file (if exists) and run the commands to ensure all
# resources are destroyed correctly. 
delete_ipv6_network() {
    echo "deleting network"

    if [ ! -f "destroy.sh" ]; then
	echo "failed to find destroy.sh, please manually remove resources ..."
	exit 1
    fi

    echo "removing resource, running destroy.sh ..."
    . destroy.sh

    echo "deleting destroy.sh ..."
    rm -rf destroy.sh

    echo "deleting firewall files ..."
    rm -rf 03_firewall.yaml 03_firewall.py
}

# Edit the configuration file (if one exists). This will add the
# fields `network`, `controlPlaneSubnet`, and `computeSubnet`.
edit_config() {
    # edit: change this when you are not running on OSX.
    # The ~ shortcut could not be used.
    HOME_DIR="/Users/${NAME}"
    ASSETS_DIR="${HOME_DIR}/dev/installer/assets"
    if [ ! -d "${ASSETS_DIR}" ]; then
	echo "missing assets directory ..."
	exit 1
    fi

    echo "select an install config to edit: "
    configs=`ls ${ASSETS_DIR}`
    select config in ${configs}
    do
	if [[ $config ]]; then
	    break
	fi
    done

    FILENAME="${ASSETS_DIR}/${config}"
    
    # Select a network for the install process
    echo "Select a VPC: "
    vpcs=`gcloud compute networks list --filter="name ~ '^${NAME}.*'" | awk 'NR > 1 {print $1}'`
    select vpc in ${vpcs}
    do
	if [[ $vpc ]]; then
	    break
	fi
    done
    export NETWORK_NAME=${vpc}
    echo "Select a control plane subnet: "
    export CONTROL_PLANE_SUBNET=$(find_subnet "${NETWORK_NAME}")
    echo "Select a compute subnet: "
    export COMPUTE_SUBNET=$(find_subnet "${NETWORK_NAME}")

    yq -i '.platform.gcp.network = env(NETWORK_NAME)' $FILENAME
    yq -i '.platform.gcp.controlPlaneSubnet = env(CONTROL_PLANE_SUBNET)' $FILENAME
    yq -i '.platform.gcp.computeSubnet = env(COMPUTE_SUBNET)' $FILENAME
}

# List the subnets attached to the network (argument 1).
find_subnet() {
    subnets=`gcloud compute networks subnets list --network "${1}" | awk 'NR > 1 {print $1}'`
    select subnet in ${subnets}
    do
	if [[ $subnet ]]; then
	    break
	fi
    done
    echo "${subnet}"
}

# Create the resources for an IPv6 network infrastructure:
# 1. network
# 2. subnets (one for control plane and compute)
# 3. router
# 4. nat
# 5. Firewall rules (including ipv4 and ipv6).
#
# The function will add the correct destroy bash statements to a file
# that is read and executed to destroy all that was created.
create_ipv6_network() {
    echo "creating network"
    select region in "us-east1" "us-central1"
    do
	if [[ $region ]]; then
	    break
	fi
    done

    echo ""
    echo "Specify EXTERNAL for public IPv6 or INTERNAL for private IPv6; EXTERNAL is the default"
    echo "access type: "
    select ipv6_access_type in "EXTERNAL" "INTERNAL"
    do
	if [[ $ipv6_access_type ]]; then
	    break
	fi
    done

    # Variables used for this creation of network resources
    NETWORK_NAME="${NAME}-${DATE}-vpc"
    SUBNETWORK_NAME_CONTROL_PLANE="${NETWORK_NAME}-control-plane-subnet"
    IPV4_RANGE_CONTROL_PLANE="10.0.0.0/17"
    SUBNETWORK_NAME_COMPUTE="${NETWORK_NAME}-compute-subnet"
    IPV4_RANGE_COMPUTE="10.0.128.0/17"
    ROUTER_NAME="${NAME}-router-${DATE}"
    NAT_CONFIG_NAME="${NAME}-nat-${DATE}"

    if [ -f "destroy.sh" ]; then
	"destroy.sh exists, please destroy resources before proceeding ..."
	exit 1
    fi
    
    # Create a new file that will be used for deleting the data that was created
    echo "#!/bin/bash" >> destroy.sh
    echo "" >> destroy.sh
    echo "" >> destroy.sh
    chmod 777 destroy.sh

    # Create the network resources
    
    gcloud compute networks create ${NETWORK_NAME} \
	   --subnet-mode=custom \
	   --enable-ula-internal-ipv6    
    
    gcloud compute networks subnets create ${SUBNETWORK_NAME_CONTROL_PLANE} \
	   --network=${NETWORK_NAME} \
	   --range=${IPV4_RANGE_CONTROL_PLANE} \
	   --stack-type=IPV4_IPV6 \
	   --ipv6-access-type=${ipv6_access_type} \
	   --region=${region}
    
    gcloud compute networks subnets create ${SUBNETWORK_NAME_COMPUTE} \
	   --network=${NETWORK_NAME} \
	   --range=${IPV4_RANGE_COMPUTE} \
	   --stack-type=IPV4_IPV6 \
	   --ipv6-access-type=${ipv6_access_type} \
	   --region=${region}
    
    gcloud compute routers create ${ROUTER_NAME} \
	   --region=${region} \
	   --network=${NETWORK_NAME}
    
    gcloud compute routers nats create ${NAT_CONFIG_NAME} \
	   --router=${ROUTER_NAME} \
	   --region=${region} \
	   --nat-all-subnet-ip-ranges \
	   --auto-allocate-nat-external-ips

    INFRA_ID="${NAME}-${DATE}"
    echo "yes | gcloud compute firewall-rules delete ${INFRA_ID}-internal-cluster" >> destroy.sh
    echo "yes | gcloud compute firewall-rules delete ${INFRA_ID}-internal-network-ipv6" >> destroy.sh
    echo "yes | gcloud compute firewall-rules delete ${INFRA_ID}-internal-network" >> destroy.sh
    echo "yes | gcloud compute firewall-rules delete ${INFRA_ID}-control-plane" >> destroy.sh
    echo "yes | gcloud compute firewall-rules delete ${INFRA_ID}-etcd" >> destroy.sh
    echo "yes | gcloud compute firewall-rules delete ${INFRA_ID}-health-checks-ipv6" >> destroy.sh
    echo "yes | gcloud compute firewall-rules delete ${INFRA_ID}-health-checks" >> destroy.sh
    echo "yes | gcloud compute firewall-rules delete ${INFRA_ID}-api-ipv6" >> destroy.sh
    echo "yes | gcloud compute firewall-rules delete ${INFRA_ID}-api" >> destroy.sh
    echo "yes | gcloud compute firewall-rules delete ${INFRA_ID}-bootstrap-in-ssh-ipv6" >> destroy.sh
    echo "yes | gcloud compute firewall-rules delete ${INFRA_ID}-bootstrap-in-ssh" >> destroy.sh

    gcloud compute firewall-rules create "${INFRA_ID}-bootstrap-in-ssh" \
	   --network ${NETWORK_NAME} \
           --allow tcp:22 \
           --direction INGRESS \
           --source-ranges '0.0.0.0/0' \
           --target-tags "${INFRA_ID}-bootstrap"

    gcloud compute firewall-rules create "${INFRA_ID}-bootstrap-in-ssh-ipv6" \
	   --network ${NETWORK_NAME} \
           --allow tcp:22 \
           --direction INGRESS \
           --source-ranges '::/0' \
           --target-tags "${INFRA_ID}-bootstrap"

    gcloud compute firewall-rules create "${INFRA_ID}-api" \
	   --network ${NETWORK_NAME} \
	   --allow tcp:6443 \
	   --direction INGRESS \
	   --source-ranges '0.0.0.0/0' \
	   --target-tags "${INFRA_ID}-master"

    gcloud compute firewall-rules create "${INFRA_ID}-api-ipv6" \
	   --network ${NETWORK_NAME} \
	   --allow tcp:6443 \
	   --direction INGRESS \
	   --source-ranges '::/0' \
	   --target-tags "${INFRA_ID}-master"
    
    gcloud compute firewall-rules create "${INFRA_ID}-health-checks" \
	   --network ${NETWORK_NAME} \
	   --allow tcp:6080,tcp:6443,tcp:22624 \
	   --direction INGRESS \
	   --source-ranges '35.191.0.0/16','130.211.0.0/22','209.85.152.0/22','209.85.204.0/22' \
	   --target-tags "${INFRA_ID}-master"

    # The source ranges are in the following page:
    # https://docs.cloud.google.com/load-balancing/docs/health-check-concepts#ip-ranges
    # See sections:
    # Global external Application Load Balancer
    # Regional external Application Load Balancer
    # External passthrough Network Load Balancer
    # Internal passthrough Network Load Balancer
    gcloud compute firewall-rules create "${INFRA_ID}-health-checks-ipv6" \
	   --network ${NETWORK_NAME} \
	   --allow tcp:6080,tcp:6443,tcp:22624 \
	   --direction INGRESS \
	   --source-ranges '2600:2d00:1:b029::/64','2600:2d00:1:1::/64','2600:1901:8001::/48' \
	   --target-tags "${INFRA_ID}-master"

    gcloud compute firewall-rules create "${INFRA_ID}-etcd" \
	   --network ${NETWORK_NAME} \
	   --allow tcp:2379-2380 \
	   --direction INGRESS \
	   --source-tags "${INFRA_ID}-master" \
	   --target-tags "${INFRA_ID}-master"

    gcloud compute firewall-rules create "${INFRA_ID}-control-plane" \
	   --network ${NETWORK_NAME} \
	   --allow tcp:10257,tcp:10259,tcp:22623 \
	   --direction INGRESS \
	   --source-tags "${INFRA_ID}-master","${INFRA_ID}-worker" \
	   --target-tags "${INFRA_ID}-master"

    gcloud compute firewall-rules create "${INFRA_ID}-internal-network" \
	   --network ${NETWORK_NAME} \
	   --allow tcp:22,icmp \
	   --direction INGRESS \
	   --source-ranges '10.0.0.0/16' \
	   --target-tags "${INFRA_ID}-master","${INFRA_ID}-worker"

    gcloud compute firewall-rules create "${INFRA_ID}-internal-network-ipv6" \
	   --network ${NETWORK_NAME} \
	   --allow tcp:22,icmp \
	   --direction INGRESS \
	   --source-ranges '::ffff:10.0.0.0/112' \
	   --target-tags "${INFRA_ID}-master","${INFRA_ID}-worker"

    gcloud compute firewall-rules create "${INFRA_ID}-internal-cluster" \
	   --network ${NETWORK_NAME} \
	   --direction INGRESS \
	   --allow udp:4789,udp:6081,udp:500,udp:4500,esp,tcp:9000-9999,tcp:10250,tcp:30000-32767,udp:30000-32767 \
	   --source-tags "${INFRA_ID}-master","${INFRA_ID}-worker" \
	   --target-tags "${INFRA_ID}-master","${INFRA_ID}-worker"
    
    echo "yes | gcloud compute routers nats delete ${NAT_CONFIG_NAME} --router=${ROUTER_NAME} --region=${region}" >> destroy.sh
    echo "yes | gcloud compute routers delete ${ROUTER_NAME} --region=${region}" >> destroy.sh
    echo "yes | gcloud compute networks subnets delete ${SUBNETWORK_NAME_COMPUTE} --region=${region}" >> destroy.sh
    echo "yes | gcloud compute networks subnets delete ${SUBNETWORK_NAME_CONTROL_PLANE} --region=${region}" >> destroy.sh
    echo "yes | gcloud compute networks delete ${NETWORK_NAME}" >> destroy.sh
}


echo "execution path: "
select exec_path in "create" "delete" "config"
do
    if [[ $exec_path ]]; then
	break
    else
	echo "invalid execution path"
	exit 1
    fi
done

if [ "${exec_path}" == "delete" ]; then
    delete_ipv6_network
elif [ "${exec_path}" == "config" ]; then
    edit_config
else
    create_ipv6_network
fi

