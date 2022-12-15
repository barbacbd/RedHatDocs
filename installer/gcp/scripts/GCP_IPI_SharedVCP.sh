#!/bin/bash
############################################################
# the purpose of this script is to create the vpc          #
# and the firewall rules for the network when testing      #
# a shared VPC IPI installation (GCP only).                #
#                                                          #
# The following is an example of what should be in         #
# the install-config.yaml file to complete this            #
# installation:                                            #
# platform:                                                #
#   gcp:                                                   #
#     networkProjectID: openshift-dev-installer            #
#     network: bbarbach-ipi-test                           #
#     computeSubnet: bbarbach-ipi-test-subnet              #
#     controlPlaneSubnet: bbarbach-ipi-test-subnet         #
#     projectID: openshift-dev-installer                   #
#     region: us-east1                                     #
#                                                          #
# The `networkProjectID` is required for IPI installs.     #
# The `network`, `computeSubnet`, and `controlPlaneSubnet` #
# are required when supplying the `networkProjectID`.      #
############################################################
set -eux

# Create manifests
openshift-install create manifests

# Create Ignition configs
openshift-install create ignition-configs

# The project name where the shared network exist.
export HOST_PROJECT="openshift-dev-installer"

# A host project account with sufficient permissions (tested with project.Owner)
export HOST_PROJECT_ACCOUNT="bbarbach@redhat.com"


export NETWORK_CIDR='10.0.0.0/16'
export MASTER_SUBNET_CIDR='10.0.0.0/19'
export WORKER_SUBNET_CIDR='10.0.32.0/19'

export CLUSTER_NAME=$(jq -r .clusterName metadata.json)
export INFRA_ID=$(jq -r .infraID metadata.json)
export PROJECT_NAME=$(jq -r .gcp.projectID metadata.json)
export REGION=$(jq -r .gcp.region metadata.json)

# default for xpn work is installer-shared-vpc
#export NETWORK_NAME="bbarbach-ipi-test"
export NETWORK_NAME="installer-shared-vpc"

# You can find this under
# -- Project
# -- -- VPC Network
# Use a network that is available and you have the permissions to alter
export HOST_PROJECT_NETWORK="https://www.googleapis.com/compute/v1/projects/openshift-dev-installer/global/networks/${NETWORK_NAME}"
# Formality - consistency from previous work
export CLUSTER_NETWORK="${HOST_PROJECT_NETWORK}"


# Grab the vpc creation script
if [ ! -f "01_vpc.py" ] ; then
    wget https://raw.githubusercontent.com/openshift/installer/master/upi/gcp/01_vpc.py
fi

if [ ! -f "01_vpc.yaml" ]; then
cat <<EOF >01_vpc.yaml
imports:
- path: 01_vpc.py
resources:
- name: cluster-vpc
  type: 01_vpc.py
  properties:
    infra_id: '${INFRA_ID}'
    region: '${REGION}'
    master_subnet_cidr: '${MASTER_SUBNET_CIDR}'
    worker_subnet_cidr: '${WORKER_SUBNET_CIDR}'
EOF
fi

# Create the deployment, this corresponds to part 1 of the above yaml
gcloud deployment-manager deployments create ${INFRA_ID}-vpc --config 01_vpc.yaml

# give a break
sleep 3.0

# Grab the firewall script
if [ ! -f "03_firewall.py" ]; then
    wget https://raw.githubusercontent.com/openshift/installer/master/upi/gcp/03_firewall.py
fi

if [ ! -f "03_firewall.yaml" ]; then
cat <<EOF >03_firewall.yaml
imports:
- path: 03_firewall.py
resources:
- name: cluster-firewall
  type: 03_firewall.py
  properties:
    allowed_external_cidr: '0.0.0.0/0'
    infra_id: '${INFRA_ID}'
    cluster_network: '${CLUSTER_NETWORK}'
    network_cidr: '${NETWORK_CIDR}'
EOF
fi

# push firewall rules for the VPC to GCP
gcloud --account=${HOST_PROJECT_ACCOUNT} --project=${HOST_PROJECT} deployment-manager deployments create ${INFRA_ID}-security-firewall --config 03_firewall.yaml

# provide the release image based on the installer version
DEFAULT_RELEASE="$(openshift-install version | grep 'release image ' | cut -d ' ' -f3 | cut -d ':' -f 2)"
echo "DEFAULT_RELEASE=${DEFAULT_RELEASE}"
RELEASE="${OPENSHIFT_RELEASE:-${DEFAULT_RELEASE}}"
export OPENSHIFT_INSTALL_RELEASE_IMAGE_OVERRIDE="registry.ci.openshift.org/ocp/release:${RELEASE}"
openshift-install create cluster --log-level DEBUG
