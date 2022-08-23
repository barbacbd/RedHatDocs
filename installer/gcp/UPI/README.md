# GCP XPN UPI Installation with Openshift Installer

This document is created to assist with installation during UPI for GCP with
a shared private virtual network or XPN.

## Initialization

All steps in this section _should_ be completed **before** the installation occurs.

For the purpose of this project, the following projects were used:
- Host: openshift-dev-installer
- XPN: openshift-installer-shared-vpc

### Account Access

You should have a service accouunt in both the host and xpn projects. These service accounts should **NOT** be the same.

The service account access (roles) for the XPN include:
- roles/compute.admin
- roles/compute.storageAdmin
- roles/deploymentmanager.editor
- roles/dns.admin
- roles/iam.securityAdmin
- roles/iam.serviceAccountAdmin
- roles/iam.serviceAccountKeyAdmin
- roles/iam.serviceAccountUser
- roles/storage.admin

If you would like to see what account roles are attached to your accouunt for a project:

```bash
get-iam-policy {project} \
    --flatten="bindings[].members" \
    --format='table(bindings.role)' \
    --filter="bindings.members:{service-account}"
```

### GCP Key configuration

Pull the service key for the account from the GCP online interface.

Move the key to `.gcp` and Make a copy of the key that can easily be switched.

```bash
# Grab the GCP Key online

cd .gcp
mv ~/Downloads/{XPN-Key}.json ./$USER-xpn-key.json

# At this point you may have another json key file
# use a copy so that we can control which is used
cp ./$USER-xpn-key.json  gcp-key.json
```

**Note**: You can verify which one of the keys is currently residing in `gcp-key.json` by checking the size and/or diff of the files.


### Configuration through gcloud

Run `gcloud config list` to view the current region, account, and project. Run `gcloud config set {param} {value}` to set the correct
information. For the purposes of this example the following config is set:

```bash
[compute]
region = us-east1
zone = us-east1-b
[core]
account = bbarbach-dev@openshift-installer-shared-vpc.iam.gserviceaccount.com
disable_usage_reporting = True
project = openshift-installer-shared-vpc
```

The `account` is the service account that you created for the XPN project.
The `project` is the name of the XPN project.
The `region` must be a valid region for the XPN project.

### Creating the install-config

_If you have not already, sym-link openshift-installer into a path that is a part of your bin._

Run `openshift-install create install-config`. The config should look something like this:

```bash
apiVersion: v1
baseDomain: installer.gcp.devcluster.openshift.com
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
  name: bbarbach-dev-xpn
platform:
  gcp:
    projectID: openshift-installer-shared-vpc
    region: us-east1
publish: External
```

The `region` and `projectID` should match the values that were setup earlier. The `baseDomain` is selected
from the options that appear during provisioning.

**NOTE**: The user _must_ add the `credentialsMode: Passthrough` to the install-config _after_ the file has been created. 

### Grabbing the correct files

Visit the [openshift-installer docs](https://github.com/openshift/installer/tree/master/upi/gcp) to get all of the python
scripts that you will need during the installation process.

The main scripts are located here:
- `GCP_UPI_SharedVCP.sh`: The main script for running the installation
- 'destroy.sh`: Destruction of _most_ artifacts created during installation

The name of the project and username in the `GCP_UPI_SharedVCP.sh` _must_ be adjusted.

## Running the Install

There are two different methods to run the install using the script provided. Those will be documented here.

### Basic

```bash
cd /path/to/oi-dev
mkdir assets
cd assets
mkdir assets


```

1. Copy all python files from openshift-install (above) into the inner-most assets directory
2. Copy the `GCP_UPI_SharedVCP.sh` and 'destroy.sh` here
3. Copy install-config.yaml to both assets directories (it will be erased from the inner-most during install)
4. Run `GCP_UPI_SharedVCP.sh`

**The installation will fail**. The machinesets will not be able to start with the current network settings.
Run the following commands to check on the machines and machinesets

`oc get machinesets -A` and `oc get machines -A`

You will notice all machines will say `FAILED`. We need to change the network interface information for these machinesets.
For each machine set (more than likely 3 if you are using the default).

`oc edit machineset {machineset-ID} -n openshift-machine-api`

Scroll down the edit page to find the `networkInterface`, this section needs to be adjusted. The `networkInterface` should look
like this (for this example):

```bash
    networkInterfaces:
    - network: installer-shared-vpc
      projectID: openshift-dev-installer
      subnetwork: installer-shared-vpc-subnet-2
```

The subnetwork comes from the value that was set in `GCP_UPI_SharedVCP.sh`. The network is also set in `GCP_UPI_SharedVCP.sh`. The
projectID is the name of the main or host project.

After all of the  machinesets have been edited, scaleup the machinesets with `oc scale machineset {machineset-ID} -n openshift-machine-api --replicas=2`.
You should see the machines go to `Provisioning` -> `Provisioned` -> `Running`.


### Adjusting the script
- make the changes to the script to auto


## Destroying

Run the `destroy.sh` from the first assets directory. It will cleanup _most_ of the artifacts and resources
created during the installation.

1. Go to GCP (online site) and destroy the remaining resources.
2. Select the host project (openshift-dev-installer).
3. Navigate to `Cloud DNS`. Search for your username (for me it was `bbarbach`).
4. Go into the resources here, and first select all records and `Delete records`.
5. After all records have been deleted, you can delete the Zone.
6. Navigate to the public DNS records. Again search for your name. **DO NOT** Delete anyone elses records. **DO NOT** delete the public zone.
7. Navigate to Deployments, delete the deployments attached to your user **ONLY**.