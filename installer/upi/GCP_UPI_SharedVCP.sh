#!/bin/bash
# For Red Hat internal use only.
#
# Following (unreleased master): Installing a cluster on GCP using Deployment Manager templates
# https://github.com/openshift/installer/blob/ce33cfb9b23d2ee5cc2f349566cd3ae0ca1bb3eb/docs/user/gcp/install_upi.md
# Even though this is in bash format, it is not intended to be executed and is for informational use only.
set -euvo pipefail
trap 'popd; CHILDREN=$(jobs -p); if test -n "${CHILDREN}"; then kill ${CHILDREN} && wait; fi' EXIT
mkdir -p "${1:-assets}"
pushd ${ASSETDIR-assets}

## ===========================================================================
## Fulfill all prerequisites, including permissions to Shared VPC subnets
## ===========================================================================
## Prerequisites
#* all prerequisites from [README](README.md)
#* the following binaries installed and in $PATH:
#  * gcloud
#  * gsutil
#* gcloud authenticated to an account with [additional](iam.md) roles:
#  * Deployment Manager Editor
#  * Service Account Key Admin
#* the following API Services enabled:
#  * Cloud Deployment Manager V2 API (deploymentmanager.googleapis.com)
#* the following files are in the assets dir:
#  * 02_dns.py  
#  * 02_lb_ext.py  
#  * 02_lb_int.py  
#  * 03_firewall.py  
#  * 03_iam.py  ￼
#  * 04_bootstrap.py  
#  * 05_control_plane.py  
#  * 06_worker.py 

## ===========================================================================
## Additional prerequisites specific to this shared vpc workflow
## ===========================================================================
#* ensure the following packages are installed
# * yum install jq python3-pip
# * pip install --user --upgrade pyyaml pyopenssl

## ===========================================================================
## Determine RHCOS_IMAGE and override RELEASE (for dev only)
## ===========================================================================
DEFAULT_RELEASE="$(openshift-install version | grep 'release image ' | cut -d ' ' -f3 | cut -d ':' -f 2)"
echo "DEFAULT_RELEASE=${DEFAULT_RELEASE}"
RELEASE="${OPENSHIFT_RELEASE:-${DEFAULT_RELEASE}}"
echo "RELEASE=${RELEASE}"
# export OPENSHIFT_INSTALL_RELEASE_IMAGE_OVERRIDE="registry.ci.openshift.org/ocp/release:${RELEASE}"
# echo "OPENSHIFT_INSTALL_RELEASE_IMAGE_OVERRIDE: ${OPENSHIFT_INSTALL_RELEASE_IMAGE_OVERRIDE}"

export RHCOS_IMAGE_NAME="$(openshift-install coreos print-stream-json | jq -r '.architectures.x86_64.images.gcp.name')"
export RHCOS_IMAGE_PROJECT="$(openshift-install coreos print-stream-json | jq -r '.architectures.x86_64.images.gcp.project')"
echo "Using image from ${RHCOS_IMAGE_NAME} in ${RHCOS_IMAGE_PROJECT}"

## ===========================================================================
## Setup variables specific to this shared vpc workflow
## =========================================================================== 
# The project name where the shared network exist.
export HOST_PROJECT="openshift-dev-installer"

# A host project account with sufficient permissions (tested with project.Owner)
export HOST_PROJECT_ACCOUNT="bbarbach@redhat.com"

# The host project network name containing the subnets.
export HOST_PROJECT_NETWORK_NAME="installer-shared-vpc"
export HOST_PROJECT_NETWORK="https://www.googleapis.com/compute/v1/projects/openshift-dev-installer/global/networks/installer-shared-vpc"

# The host project master subnet where the control plane should be provisioned.
export HOST_PROJECT_CONTROL_SUBNET_NAME="installer-shared-vpc-subnet-1"
export HOST_PROJECT_CONTROL_SUBNET="https://www.googleapis.com/compute/v1/projects/openshift-dev-installer/regions/us-east1/subnetworks/installer-shared-vpc-subnet-1"

# The host project worker subnet where the computes should be provisioned.
export HOST_PROJECT_COMPUTE_SUBNET_NAME="installer-shared-vpc-subnet-2"
export HOST_PROJECT_COMPUTE_SUBNET="https://www.googleapis.com/compute/v1/projects/openshift-dev-installer/regions/us-east1/subnetworks/installer-shared-vpc-subnet-2"

# The host project worker subnet where the computes should be proviinstall-config.yamlpy); do ln -s $file; done

## ===========================================================================
## Create Ignition configs
## ===========================================================================

# Create an install config
# Option 1) need to modify pull-secreat
#oi --dir . -i install-config.back create install-config

# Option 2) pull secreate is already modified 
# cp install-config.back install-config.yaml
# openshift-install create install-config


#cat <<EOF >install-config.yaml
#apiVersion: v1
#baseDomain: installer.gcp.devcluster.openshift.com
#compute:
#- architecture: amd64
#  hyperthreading: Enabled
#  name: worker
#  platform: {}
#  replicas: 3
#controlPlane:
#  architecture: amd64
#  hyperthreading: Enabled
#  name: master
#  platform: {}
#  replicas: 3
#metadata:
#  creationTimestamp: null
#  name: tzivkovi
#networking:
#  clusterNetwork:
#  - cidr: 10.128.0.0/14
#    hostPrefix: 23
#  machineNetwork:
#  - cidr: 10.0.0.0/16
#  networkType: OpenShiftSDN
#  serviceNetwork:
#  - 172.30.0.0/16
#platform:
#  gcp:
#    projectID: openshift-installer-shared-vpc
#    region: us-east1
#publish: Internal
#pullSecret: <secret>
#sshKey: |
#  <secret>
#EOF

# Empty the compute pool
# REMOVED TO STOP WORKERES
# python3 -c '
# import yaml;
# path = "install-config.yaml";
# data = yaml.load(open(path));
# data["compute"][0]["replicas"] = 0;
# open(path, "w").write(yaml.dump(data, default_flow_style=False))'

# Enable private cluster setting
python3 -c '
import yaml;
path = "install-config.yaml";
data = yaml.safe_load(open(path));
data["publish"] = "Internal";
open(path, "w").write(yaml.dump(data, default_flow_style=False))'

# Create manifests
openshift-install create manifests

# Remove control plane machines
rm -f openshift/99_openshift-cluster-api_master-machines-*.yaml

# Remove compute machinesets
# REMOVED TO STOP WORKERES
# rm -f openshift/99_openshift-cluster-api_worker-machineset-*.yaml

# Make control-plane nodes unschedulable
# REMOVED TO STOP WORKERES
# python3 -c '
# import yaml;
# path = "manifests/cluster-scheduler-02-config.yml";
# data = yaml.load(open(path));
# data["spec"]["mastersSchedulable"] = False;
# open(path, "w").write(yaml.dump(data, default_flow_style=False))'

# Remove DNS Zones
python3 -c '
import yaml;
path = "manifests/cluster-dns-02-config.yml";
data = yaml.safe_load(open(path));
del data["spec"]["privateZone"];
open(path, "w").write(yaml.dump(data, default_flow_style=False))'

# Update the cloud-provider manifest
sed -i "s/    subnetwork-name.*/    network-project-id = ${HOST_PROJECT}\\n    network-name    = ${HOST_PROJECT_NETWORK_NAME}\\n    subnetwork-name = ${HOST_PROJECT_COMPUTE_SUBNET_NAME}/" manifests/cloud-provider-config.yaml

# Remove publish:internal bits
python3 -c '
import yaml;
path = "manifests/cluster-ingress-default-ingresscontroller.yaml";
data = yaml.safe_load(open(path));
data["spec"]["endpointPublishingStrategy"]["loadBalancer"]["scope"] = "External";
open(path, "w").write(yaml.dump(data, default_flow_style=False))'

# Create Ignition configs
openshift-install create ignition-configs

## ===========================================================================
## Export variables to be used in examples below.
## ===========================================================================

export BASE_DOMAIN='installer.gcp.devcluster.openshift.com'
export BASE_DOMAIN_ZONE_NAME='installer-public-zone'

export NETWORK_CIDR='10.0.0.0/16'
export MASTER_SUBNET_CIDR='10.0.0.0/19'
export WORKER_SUBNET_CIDR='10.0.32.0/19'

export KUBECONFIG=auth/kubeconfig
export CLUSTER_NAME=$(jq -r .clusterName metadata.json)
export INFRA_ID=$(jq -r .infraID metadata.json)
export PROJECT_NAME=$(jq -r .gcp.projectID metadata.json)
export REGION=$(jq -r .gcp.region metadata.json)
ZONES=$(gcloud compute regions describe ${REGION} --format=json)
export ZONE_0=$(echo "${ZONES}" | jq -r .zones[0] | cut -d "/" -f9)
export ZONE_1=$(echo "${ZONES}" | jq -r .zones[1] | cut -d "/" -f9)
export ZONE_2=$(echo "${ZONES}" | jq -r .zones[2] | cut -d "/" -f9)

export MASTER_IGNITION=$(cat master.ign)
export WORKER_IGNITION=$(cat worker.ign)

## ===========================================================================
## Configure VPC variables (based on pre-exsisting Shared VPC)
## ===========================================================================

export CLUSTER_NETWORK="${HOST_PROJECT_NETWORK}"
export CONTROL_SUBNET="${HOST_PROJECT_CONTROL_SUBNET}"
export COMPUTE_SUBNET="${HOST_PROJECT_COMPUTE_SUBNET}"

## ===========================================================================
## Create the dns-private-zone
## using --account and --project to access the host project
## ===========================================================================

cat <<EOF >02_infra_dns.yaml
imports:
- path: 02_dns.py
resources:
- name: cluster-dns
  type: 02_dns.py
  properties:
    infra_id: '${INFRA_ID}'
    cluster_domain: '${CLUSTER_NAME}.${BASE_DOMAIN}'
    cluster_network: '${CLUSTER_NETWORK}'
EOF

gcloud --account=${HOST_PROJECT_ACCOUNT} --project=${HOST_PROJECT} deployment-manager deployments create ${INFRA_ID}-infra-dns --config 02_infra_dns.yaml

## ===========================================================================
## Create DNS entries and load balancers (excluding DNS)
## ===========================================================================

cat <<EOF >02_infra.yaml
imports:
- path: 02_dns.py
- path: 02_lb_ext.py
- path: 02_lb_int.py
resources:
- name: cluster-lb-ext
  type: 02_lb_ext.py
  properties:
    infra_id: '${INFRA_ID}'
    region: '${REGION}'
- name: cluster-lb-int
  type: 02_lb_int.py
  properties:
    cluster_network: '${CLUSTER_NETWORK}'
    control_subnet: '${CONTROL_SUBNET}'
    infra_id: '${INFRA_ID}'
    region: '${REGION}'
    zones:
    - '${ZONE_0}'
    - '${ZONE_1}'
    - '${ZONE_2}'
EOF

# Create the infra resources
gcloud deployment-manager deployments create ${INFRA_ID}-infra --config 02_infra.yaml

## ===========================================================================
## Configure infra variables
## ===========================================================================

export CLUSTER_IP=$(gcloud compute addresses describe ${INFRA_ID}-cluster-ip --region=${REGION} --format json | jq -r .address)
export CLUSTER_PUBLIC_IP=$(gcloud compute addresses describe ${INFRA_ID}-cluster-public-ip --region=${REGION} --format json | jq -r .address)

## ===========================================================================
## Add DNS entries
## using --account and --project to access the host project
## ===========================================================================

if [ -f transaction.yaml ]; then rm transaction.yaml; fi
gcloud --account=${HOST_PROJECT_ACCOUNT} --project=${HOST_PROJECT} dns record-sets transaction start --zone ${INFRA_ID}-private-zone
gcloud --account=${HOST_PROJECT_ACCOUNT} --project=${HOST_PROJECT} dns record-sets transaction add ${CLUSTER_IP} --name api.${CLUSTER_NAME}.${BASE_DOMAIN}. --ttl 60 --type A --zone ${INFRA_ID}-private-zone
gcloud --account=${HOST_PROJECT_ACCOUNT} --project=${HOST_PROJECT} dns record-sets transaction add ${CLUSTER_IP} --name api-int.${CLUSTER_NAME}.${BASE_DOMAIN}. --ttl 60 --type A --zone ${INFRA_ID}-private-zone
gcloud --account=${HOST_PROJECT_ACCOUNT} --project=${HOST_PROJECT} dns record-sets transaction execute --zone ${INFRA_ID}-private-zone

if [ -f transaction.yaml ]; then rm transaction.yaml; fi
gcloud --account=${HOST_PROJECT_ACCOUNT} --project=${HOST_PROJECT} dns record-sets transaction start --zone ${BASE_DOMAIN_ZONE_NAME}
gcloud --account=${HOST_PROJECT_ACCOUNT} --project=${HOST_PROJECT} dns record-sets transaction add ${CLUSTER_PUBLIC_IP} --name api.${CLUSTER_NAME}.${BASE_DOMAIN}. --ttl 60 --type A --zone ${BASE_DOMAIN_ZONE_NAME}
gcloud --account=${HOST_PROJECT_ACCOUNT} --project=${HOST_PROJECT} dns record-sets transaction execute --zone ${BASE_DOMAIN_ZONE_NAME}

## ===========================================================================
## Add firewall rules
## using --account and --project to access the host project
## ===========================================================================

# Create 03_security_firewall.yaml
cat <<EOF >03_security_firewall.yaml
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

gcloud --account=${HOST_PROJECT_ACCOUNT} --project=${HOST_PROJECT} deployment-manager deployments create ${INFRA_ID}-security-firewall --config 03_security_firewall.yaml

## ===========================================================================
## Create firewall rules and IAM roles (Excluding firewall rules)
## ===========================================================================

cat <<EOF >03_security.yaml
imports:
- path: 03_firewall.py
- path: 03_iam.py
resources:
- name: cluster-iam
  type: 03_iam.py
  properties:
    infra_id: '${INFRA_ID}'
EOF

gcloud deployment-manager deployments create ${INFRA_ID}-security --config 03_security.yaml

## ===========================================================================
## Configure security variables
## ===========================================================================

sleep 5 # Give service accounts a moment settle.
export MASTER_SERVICE_ACCOUNT=$(gcloud iam service-accounts list --filter "email~^${INFRA_ID}-m@${PROJECT_NAME}." --format json | jq -r '.[0].email')
export WORKER_SERVICE_ACCOUNT=$(gcloud iam service-accounts list --filter "email~^${INFRA_ID}-w@${PROJECT_NAME}." --format json | jq -r '.[0].email')

echo $MASTER_SERVICE_ACCOUNT
## ===========================================================================
## Add required roles to IAM service accounts
## ===========================================================================

gcloud projects add-iam-policy-binding ${PROJECT_NAME} --member "serviceAccount:${MASTER_SERVICE_ACCOUNT}" --role "roles/compute.instanceAdmin"
gcloud projects add-iam-policy-binding ${PROJECT_NAME} --member "serviceAccount:${MASTER_SERVICE_ACCOUNT}" --role "roles/compute.networkAdmin"
gcloud projects add-iam-policy-binding ${PROJECT_NAME} --member "serviceAccount:${MASTER_SERVICE_ACCOUNT}" --role "roles/compute.securityAdmin"
gcloud projects add-iam-policy-binding ${PROJECT_NAME} --member "serviceAccount:${MASTER_SERVICE_ACCOUNT}" --role "roles/iam.serviceAccountUser"
gcloud projects add-iam-policy-binding ${PROJECT_NAME} --member "serviceAccount:${MASTER_SERVICE_ACCOUNT}" --role "roles/storage.admin"

gcloud projects add-iam-policy-binding ${PROJECT_NAME} --member "serviceAccount:${WORKER_SERVICE_ACCOUNT}" --role "roles/compute.viewer"
gcloud projects add-iam-policy-binding ${PROJECT_NAME} --member "serviceAccount:${WORKER_SERVICE_ACCOUNT}" --role "roles/storage.admin"

## ===========================================================================
## Ensure the new sevice accounts have access to the Shared VPC subnets
## using --account and --project to access the host project
## ===========================================================================

gcloud --account=${HOST_PROJECT_ACCOUNT} --project=${HOST_PROJECT} projects add-iam-policy-binding ${HOST_PROJECT} --member "serviceAccount:${MASTER_SERVICE_ACCOUNT}" --role "roles/compute.networkViewer"

gcloud --account=${HOST_PROJECT_ACCOUNT} --project=${HOST_PROJECT} compute networks subnets add-iam-policy-binding "${HOST_PROJECT_CONTROL_SUBNET}" --member "serviceAccount:${MASTER_SERVICE_ACCOUNT}" --role "roles/compute.networkUser"
gcloud --account=${HOST_PROJECT_ACCOUNT} --project=${HOST_PROJECT} compute networks subnets add-iam-policy-binding "${HOST_PROJECT_CONTROL_SUBNET}" --member "serviceAccount:${WORKER_SERVICE_ACCOUNT}" --role "roles/compute.networkUser"

gcloud --account=${HOST_PROJECT_ACCOUNT} --project=${HOST_PROJECT} compute networks subnets add-iam-policy-binding "${HOST_PROJECT_COMPUTE_SUBNET}" --member "serviceAccount:${MASTER_SERVICE_ACCOUNT}" --role "roles/compute.networkUser"
gcloud --account=${HOST_PROJECT_ACCOUNT} --project=${HOST_PROJECT} compute networks subnets add-iam-policy-binding "${HOST_PROJECT_COMPUTE_SUBNET}" --member "serviceAccount:${WORKER_SERVICE_ACCOUNT}" --role "roles/compute.networkUser"

## ===========================================================================
## Generate a service-account-key for signing the bootstrap.ign url
## ===========================================================================

gcloud iam service-accounts keys create service-account-key.json --iam-account=${MASTER_SERVICE_ACCOUNT}

## ===========================================================================
## Create the cluster image.
## ===========================================================================

echo "Creating image from ${RHCOS_IMAGE_NAME} in ${RHCOS_IMAGE_PROJECT}"
gcloud compute images create "${INFRA_ID}-rhcos-image" --source-image="${RHCOS_IMAGE_NAME}" --source-image-project="${RHCOS_IMAGE_PROJECT}"
export CLUSTER_IMAGE=$(gcloud compute images describe ${INFRA_ID}-rhcos-image --format json | jq -r .selfLink)

## ===========================================================================
## Upload the bootstrap.ign to a new bucket
## ===========================================================================

gsutil mb gs://${INFRA_ID}-bootstrap-ignition
gsutil cp bootstrap.ign gs://${INFRA_ID}-bootstrap-ignition/
export BOOTSTRAP_IGN=$(gsutil signurl -d 1h service-account-key.json gs://${INFRA_ID}-bootstrap-ignition/bootstrap.ign | grep "^gs:" | awk '{print $5}')

## ===========================================================================
## Launch temporary bootstrap resources
## ===========================================================================

cat <<EOF >04_bootstrap.yaml
imports:
- path: 04_bootstrap.py
resources:
- name: cluster-bootstrap
  type: 04_bootstrap.py
  properties:
    infra_id: '${INFRA_ID}'
    region: '${REGION}'
    zone: '${ZONE_0}'
    cluster_network: '${CLUSTER_NETWORK}'
    control_subnet: '${CONTROL_SUBNET}'
    image: '${CLUSTER_IMAGE}'
    machine_type: 'n1-standard-4'
    root_volume_size: '128'
    bootstrap_ign: '${BOOTSTRAP_IGN}'
EOF

gcloud deployment-manager deployments create ${INFRA_ID}-bootstrap --config 04_bootstrap.yaml

## ===========================================================================
## Add the bootstrap instance to the load balancers
## ===========================================================================

gcloud compute instance-groups unmanaged add-instances ${INFRA_ID}-bootstrap-ig --zone=${ZONE_0} --instances=${INFRA_ID}-bootstrap
gcloud compute backend-services add-backend ${INFRA_ID}-api-internal-backend-service --region=${REGION} --instance-group=${INFRA_ID}-bootstrap-ig --instance-group-zone=${ZONE_0}

## ===========================================================================
## Launch permanent control plane
## ===========================================================================

cat <<EOF >05_control_plane.yaml
imports:
- path: 05_control_plane.py
resources:
- name: cluster-control-plane
  type: 05_control_plane.py
  properties:
    infra_id: '${INFRA_ID}'
    zones:
    - '${ZONE_0}'
    - '${ZONE_1}'
    - '${ZONE_2}'
    control_subnet: '${CONTROL_SUBNET}'
    image: '${CLUSTER_IMAGE}'
    machine_type: 'n1-standard-4'
    root_volume_size: '128'
    service_account_email: '${MASTER_SERVICE_ACCOUNT}'
    ignition: '${MASTER_IGNITION}'
EOF

gcloud deployment-manager deployments create ${INFRA_ID}-control-plane --config 05_control_plane.yaml

## ===========================================================================
## Configure control plane variables
## ===========================================================================

export MASTER0_IP=$(gcloud compute instances describe ${INFRA_ID}-master-0 --zone ${ZONE_0} --format json | jq -r .networkInterfaces[0].networkIP)
export MASTER1_IP=$(gcloud compute instances describe ${INFRA_ID}-master-1 --zone ${ZONE_1} --format json | jq -r .networkInterfaces[0].networkIP)
export MASTER2_IP=$(gcloud compute instances describe ${INFRA_ID}-master-2 --zone ${ZONE_2} --format json | jq -r .networkInterfaces[0].networkIP)

## ===========================================================================
## Add DNS entries for control plane etcd
## using --account and --project to access the host project
## ===========================================================================

if [ -f transaction.yaml ]; then rm transaction.yaml; fi
gcloud --account=${HOST_PROJECT_ACCOUNT} --project=${HOST_PROJECT}  dns record-sets transaction start --zone ${INFRA_ID}-private-zone
gcloud --account=${HOST_PROJECT_ACCOUNT} --project=${HOST_PROJECT}  dns record-sets transaction add ${MASTER0_IP} --name etcd-0.${CLUSTER_NAME}.${BASE_DOMAIN}. --ttl 60 --type A --zone ${INFRA_ID}-private-zone
gcloud --account=${HOST_PROJECT_ACCOUNT} --project=${HOST_PROJECT}  dns record-sets transaction add ${MASTER1_IP} --name etcd-1.${CLUSTER_NAME}.${BASE_DOMAIN}. --ttl 60 --type A --zone ${INFRA_ID}-private-zone
gcloud --account=${HOST_PROJECT_ACCOUNT} --project=${HOST_PROJECT}  dns record-sets transaction add ${MASTER2_IP} --name etcd-2.${CLUSTER_NAME}.${BASE_DOMAIN}. --ttl 60 --type A --zone ${INFRA_ID}-private-zone
gcloud --account=${HOST_PROJECT_ACCOUNT} --project=${HOST_PROJECT}  dns record-sets transaction add \
  "0 10 2380 etcd-0.${CLUSTER_NAME}.${BASE_DOMAIN}." \
  "0 10 2380 etcd-1.${CLUSTER_NAME}.${BASE_DOMAIN}." \
  "0 10 2380 etcd-2.${CLUSTER_NAME}.${BASE_DOMAIN}." \
  --name _etcd-server-ssl._tcp.${CLUSTER_NAME}.${BASE_DOMAIN}. --ttl 60 --type SRV --zone ${INFRA_ID}-private-zone
gcloud --account=${HOST_PROJECT_ACCOUNT} --project=${HOST_PROJECT} dns record-sets transaction execute --zone ${INFRA_ID}-private-zone

## ===========================================================================
## Add control plane instances to load balancers
## ===========================================================================

gcloud compute instance-groups unmanaged add-instances ${INFRA_ID}-master-${ZONE_0}-ig --zone=${ZONE_0} --instances=${INFRA_ID}-master-0
gcloud compute instance-groups unmanaged add-instances ${INFRA_ID}-master-${ZONE_1}-ig --zone=${ZONE_1} --instances=${INFRA_ID}-master-1
gcloud compute instance-groups unmanaged add-instances ${INFRA_ID}-master-${ZONE_2}-ig --zone=${ZONE_2} --instances=${INFRA_ID}-master-2

gcloud compute target-pools add-instances ${INFRA_ID}-api-target-pool --instances-zone="${ZONE_0}" --instances=${INFRA_ID}-master-0
gcloud compute target-pools add-instances ${INFRA_ID}-api-target-pool --instances-zone="${ZONE_1}" --instances=${INFRA_ID}-master-1
gcloud compute target-pools add-instances ${INFRA_ID}-api-target-pool --instances-zone="${ZONE_2}" --instances=${INFRA_ID}-master-2

## ===========================================================================
## Launch additional compute nodes
## ===========================================================================

cat <<EOF >06_worker.yaml
imports:
- path: 06_worker.py
resources:
- name: 'w-0'
  type: 06_worker.py
  properties:
    infra_id: '${INFRA_ID}'
    zone: '${ZONE_0}'
    compute_subnet: '${COMPUTE_SUBNET}'
    image: '${CLUSTER_IMAGE}'
    machine_type: 'n1-standard-4'
    root_volume_size: '128'
    service_account_email: '${WORKER_SERVICE_ACCOUNT}'
    ignition: '${WORKER_IGNITION}'
- name: 'w-1'
  type: 06_worker.py
  properties:
    infra_id: '${INFRA_ID}'
    zone: '${ZONE_1}'
    compute_subnet: '${COMPUTE_SUBNET}'
    image: '${CLUSTER_IMAGE}'
    machine_type: 'n1-standard-4'
    root_volume_size: '128'
    service_account_email: '${WORKER_SERVICE_ACCOUNT}'
    ignition: '${WORKER_IGNITION}'
- name: 'w-2'
  type: 06_worker.py
  properties:
    infra_id: '${INFRA_ID}'
    zone: '${ZONE_2}'
    compute_subnet: '${COMPUTE_SUBNET}'
    image: '${CLUSTER_IMAGE}'
    machine_type: 'n1-standard-4'
    root_volume_size: '128'
    service_account_email: '${WORKER_SERVICE_ACCOUNT}'
    ignition: '${WORKER_IGNITION}'
EOF
# REMOVED TO STOP WORKERES
# gcloud deployment-manager deployments create ${INFRA_ID}-worker --config 06_worker.yaml

## ===========================================================================
## Monitor for bootstrap-complete
## ===========================================================================

openshift-install --log-level=debug wait-for bootstrap-complete

## ===========================================================================
## Destroy bootstrap resources
## ===========================================================================

gcloud compute backend-services remove-backend ${INFRA_ID}-api-internal-backend-service --region=${REGION} --instance-group=${INFRA_ID}-bootstrap-ig --instance-group-zone=${ZONE_0}
gsutil rm gs://${INFRA_ID}-bootstrap-ignition/bootstrap.ign
gsutil rb gs://${INFRA_ID}-bootstrap-ignition
gcloud deployment-manager deployments delete -q ${INFRA_ID}-bootstrap

## ===========================================================================
## Approving the CSR requests for nodes
## NOTE: The system:node will not appear until the system:serviceaccount has been approved.
## ===========================================================================

function approve_csrs() {
  while true; do
    oc get csr -ojson | jq -r '.items[] | select(.status == {} ) | .metadata.name' | xargs --no-run-if-empty oc adm certificate approve
    sleep 15 & wait
  done
}
approve_csrs &

## ===========================================================================
## Add the Ingress DNS Records
## using --account and --project to access the host project
## ===========================================================================

# Wait for the default-router to have an external ip...(and not <pending>)
# $ oc -n openshift-ingress get service router-default
# NAME             TYPE           CLUSTER-IP      EXTERNAL-IP      PORT(S)                      AGE
# router-default   LoadBalancer   172.30.18.154   35.233.157.184   80:32288/TCP,443:31215/TCP   98
export ROUTER_IP=$(oc -n openshift-ingress get service router-default --no-headers | awk '{print $4}')
while [[ "$ROUTER_IP" == "" || "$ROUTER_IP" == "<pending>" ]]; do
  sleep 10;
  export ROUTER_IP=$(oc -n openshift-ingress get service router-default --no-headers | awk '{print $4}')
done

# Create default router dns entries

if [ -f transaction.yaml ]; then rm transaction.yaml; fi
gcloud --account=${HOST_PROJECT_ACCOUNT} --project=${HOST_PROJECT} dns record-sets transaction start --zone ${INFRA_ID}-private-zone
gcloud --account=${HOST_PROJECT_ACCOUNT} --project=${HOST_PROJECT} dns record-sets transaction add ${ROUTER_IP} --name \*.apps.${CLUSTER_NAME}.${BASE_DOMAIN}. --ttl 300 --type A --zone ${INFRA_ID}-private-zone
gcloud --account=${HOST_PROJECT_ACCOUNT} --project=${HOST_PROJECT} dns record-sets transaction execute --zone ${INFRA_ID}-private-zone

if [ -f transaction.yaml ]; then rm transaction.yaml; fi
gcloud --account=${HOST_PROJECT_ACCOUNT} --project=${HOST_PROJECT} dns record-sets transaction start --zone ${BASE_DOMAIN_ZONE_NAME}
gcloud --account=${HOST_PROJECT_ACCOUNT} --project=${HOST_PROJECT} dns record-sets transaction add ${ROUTER_IP} --name \*.apps.${CLUSTER_NAME}.${BASE_DOMAIN}. --ttl 300 --type A --zone ${BASE_DOMAIN_ZONE_NAME}
gcloud --account=${HOST_PROJECT_ACCOUNT} --project=${HOST_PROJECT} dns record-sets transaction execute --zone ${BASE_DOMAIN_ZONE_NAME}

## ===========================================================================
## Add the Ingress firewall rules (optional)
## using --account and --project to access the host project
## ===========================================================================

gcloud --account=${HOST_PROJECT_ACCOUNT} --project=${HOST_PROJECT} compute firewall-rules create --allow='tcp:30000-32767,udp:30000-32767' --network="${CLUSTER_NETWORK}" --source-ranges='130.211.0.0/22,35.191.0.0/16,209.85.152.0/22,209.85.204.0/22' --target-tags="${INFRA_ID}-master,${INFRA_ID}-worker" ${INFRA_ID}-ingress-hc

gcloud --account=${HOST_PROJECT_ACCOUNT} --project=${HOST_PROJECT} compute firewall-rules create --allow='tcp:80,tcp:443' --network="${CLUSTER_NETWORK}" --source-ranges="0.0.0.0/0" --target-tags="${INFRA_ID}-master,${INFRA_ID}-worker" ${INFRA_ID}-ingress

## ===========================================================================
## Monitor for cluster completion
## ===========================================================================

openshift-install --log-level=debug wait-for install-complete
