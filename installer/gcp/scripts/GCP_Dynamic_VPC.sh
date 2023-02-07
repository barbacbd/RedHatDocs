#!/bin/bash

# This script is intended to manually create a shared VPC and all
# required resources for the shared vpc to be accessible by the
# user via a openshift-install

# save the data to [re]set the gcloud configuration when the script has finished
ORIGINAL_ACCOUNT=`gcloud config configurations list | grep True | awk '{print $1}'`

# Note: xpn is a set configuration in GCloud for the author.
# If another user wishes to edit this file, the configuration that allows
# access to the service project should be used in this case.
gcloud config configurations activate xpn
# get the name of the service account
XPN_SERVICE_ACCOUNT=`gcloud config get-value account`

# Note: normal is a set configuration in GCloud for the author.
# If another user wishes to edit this file, the configuration that allows
# access to the host project should be used in this case.
gcloud config configurations activate normal

REGION="us-central1"
INSTANCE_PREFIX="${USER}"  # change if this is not the user for GCP
CLUSTER_NAME="${INSTANCE_PREFIX}-ci-test"
HOST_PROJECT_CONTROL_SUBNET="${INSTANCE_PREFIX}-subnet-1"
HOST_PROJECT_COMPUTE_SUBNET="${INSTANCE_PREFIX}-subnet-2"
HOST_PROJECT_NETWORK="${INSTANCE_PREFIX}-vpc"
NAT_NAME="${INSTANCE_PREFIX}-nat"
# The subnet CIDR values should be reachable via the 'network' section of the install config
CONTROL_SUBNET_CIDR="10.0.64.0/19"
COMPUTE_SUBNET_CIDR="10.0.128.0/19"

# The following variables are set for the install config file
PULL_SECRET=`cat ~/.docker/config.json`
# Set your ssh public key file here to read the data for install config
SSH_PUBLIC_KEY_FILE="/home/${USER}/.ssh/${USER}.pub"
SSH_DATA=`cat ${SSH_PUBLIC_KEY_FILE}`
# grab the name of the project from the current gcloud configuration. See above
# for more information regarding the active gcloud configuration
HOST_PROJECT=`gcloud config get-value project`


function ResetOriginalAccount {
    echo "Setting the gcloud account back to the original: ${ORIGINAL_ACCOUNT}"
    gcloud config configurations activate $ORIGINAL_ACCOUNT
}

function RunInstall {
    # Create the new VPC for this CI job
    gcloud compute networks create "${HOST_PROJECT_NETWORK}" \
	   --bgp-routing-mode=regional \
	   --subnet-mode=custom

    # Create the subnets for the VPC dynamically for this CI job
    gcloud compute networks subnets create "${HOST_PROJECT_CONTROL_SUBNET}" \
           --network "${HOST_PROJECT_NETWORK}" \
           --range="${CONTROL_SUBNET_CIDR}" \
           --description "Control subnet creation for CI job GCP xpn" \
           --region "${REGION}"

    gcloud compute networks subnets create "${HOST_PROJECT_COMPUTE_SUBNET}" \
           --network "${HOST_PROJECT_NETWORK}" \
           --range="${COMPUTE_SUBNET_CIDR}" \
           --description "Compute subnet creation for CI job GCP xpn" \
           --region "${REGION}"

    # Create a router to ensure that traffic can reach the destinations
    gcloud compute routers create "${INSTANCE_PREFIX}" \
	   --network "${HOST_PROJECT_NETWORK}" \
	   --description "Router for the CI job for GCP xpn" \
	   --region "${REGION}"

    gcloud compute routers nats create "${NAT_NAME}" \
	   --router="${INSTANCE_PREFIX}" \
	   --region="${REGION}" \
	   --auto-allocate-nat-external-ips \
	   --nat-all-subnet-ip-ranges

    # Allow traffic to pass with firewall rules
    gcloud compute firewall-rules create "${INSTANCE_PREFIX}" \
	   --network "${HOST_PROJECT_NETWORK}" \
	   --allow tcp:22,icmp

    # associate the user with the xpn service account
    gcloud beta compute networks subnets get-iam-policy "${HOST_PROJECT_CONTROL_SUBNET}" \
	   --project "${HOST_PROJECT}" --region "${REGION}" --format json > subnet-policy.json

    cat << EOF > subnet-policy.json
{
  "bindings": [
  {
     "members": [
           "serviceAccount:${XPN_SERVICE_ACCOUNT}"
        ],
        "role": "roles/compute.networkUser"
  }
  ],
  "etag": "ACAB"
}
EOF

    gcloud beta compute networks subnets set-iam-policy "${HOST_PROJECT_COMPUTE_SUBNET}" \
	   subnet-policy.json \
	   --project "${HOST_PROJECT}" \
	   --region "${REGION}"

    gcloud beta compute networks subnets set-iam-policy "${HOST_PROJECT_CONTROL_SUBNET}" \
	   subnet-policy.json \
	   --project "${HOST_PROJECT}" \
	   --region "${REGION}"

    # remove the policy created above
    rm -rf subnet-policy.json

    # change the configuration back
    gcloud config configurations activate xpn
    SERVICE_PROJECT=`gcloud config get-value project`

    if [ ! -f "install-config.yaml" ]; then
	cat << EOF > install-config.yaml
additionalTrustBundlePolicy: Proxyonly
apiVersion: v1
baseDomain: installer.gcpxpn.devcluster.openshift.com
credentialsMode: Passthrough
compute:
- architecture: amd64
  hyperthreading: Enabled
  name: worker
  platform: {}
  replicas: 3
controlPlane:
  architecture: amd64
  hyperthreading: Enabled
  name: master
  platform: {}
  replicas: 3
metadata:
  creationTimestamp: null
  name: ${CLUSTER_NAME}
networking:
  clusterNetwork:
  - cidr: 10.128.0.0/14
    hostPrefix: 23
  machineNetwork:
  - cidr: 10.0.0.0/16
  networkType: OVNKubernetes
  serviceNetwork:
  - 172.30.0.0/16
platform:
  gcp:
    projectID: ${SERVICE_PROJECT}
    region: ${REGION}
    network: ${HOST_PROJECT_NETWORK}
    computeSubnet: ${HOST_PROJECT_COMPUTE_SUBNET}
    controlPlaneSubnet: ${HOST_PROJECT_CONTROL_SUBNET}
    networkProjectID: ${HOST_PROJECT}
publish: External
pullSecret: '${PULL_SECRET}'
sshKey: |
  ${SSH_DATA}
EOF
    fi

    # override the release image
    if [[ -z "${OPENSHIFT_INSTALL_RELEASE_IMAGE_OVERRIDE}" ]]; then
	DEFAULT_RELEASE="$(openshift-install version | grep 'release image ' | cut -d ' ' -f3 | cut -d ':' -f 2)"
	echo "DEFAULT_RELEASE=${DEFAULT_RELEASE}"
	RELEASE="${OPENSHIFT_RELEASE:-${DEFAULT_RELEASE}}"
	export OPENSHIFT_INSTALL_RELEASE_IMAGE_OVERRIDE="registry.ci.openshift.org/ocp/release:${RELEASE}"
    fi

    openshift-install create cluster --log-level=DEBUG

    ResetOriginalAccount
}

function DestroyCluster {
    gcloud config configurations activate xpn

    # destroy the cluster - but the xpn account needs to be active
    openshift-install destroy cluster --log-level=DEBUG

    gcloud config configurations activate normal
    gcloud compute firewall-rules delete "${INSTANCE_PREFIX}"
    gcloud compute routers nats delete "${NAT_NAME}" --router="${INSTANCE_PREFIX}" --region="${REGION}"
    gcloud compute routers delete "${INSTANCE_PREFIX}" --region "${REGION}"
    gcloud compute networks subnets delete "${HOST_PROJECT_CONTROL_SUBNET}" --region "${REGION}"
    gcloud compute networks subnets delete "${HOST_PROJECT_COMPUTE_SUBNET}" --region "${REGION}"
    gcloud compute networks delete "${HOST_PROJECT_NETWORK}"

    ResetOriginalAccount
}

case "${1:-}" in
    'install')
	RunInstall
	;;
    'destroy')
	DestroyCluster
	;;
    *)
	ResetOriginalAccount

	echo ''
	echo 'Please select from the following commands:'
	echo ''
	echo '    install   Run the installation'
	echo '    destroy   Run the cleanup'
	echo ''
	;;
esac
