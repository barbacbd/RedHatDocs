# GCP 

This document is put together to assist with information regarding the GCP platform while working with the openshift installer and the installed cluster.
<br><br>

## Table of contents

  * [IPI Installations](#ipi-installations)
     * [Base IPI Installation](#base-ipi-installation)
     * [Bring your own hosted zones](#bring-your-own-hosted-zones)
     * [Shared VPN IPI](#shared-vpn-ipi)
     * [Private Cluster](#private-cluster)
  * [UPI Installations](#upi-installations)
     * [Shared VPN UPI](#shared-vpn-upi)
        * [Initialization](#initialization)
        * [Account Access](#account-access)
        * [Key Configuration](#gcp-key-configuration)
        * [GCloud Configuration](#configuration-through-gcloud)
        * [Install Config](#creating-the-install-config)
        * [Run the install](#running-the-install)
        * [Destroying Resources](#destroying-resources)
   * [GCP Resource Manipulation](#gcp-resource-manipulation)
      * [Adding Disks](#adding-disks)
   * [GCloud CLI Authentication](#gcloud-cli-authentication)
   * [Troubleshooting](#troubleshooting)
      * [Failure During Kube API](#failure-during-kube-api)
      * [Investigate gcp resource errors](#investigate-gcp-resource-errors)


## IPI Installations 

The IPI installations are typically the more straight forward installation methods. The installer will walk the user through an opinionated install configuration, however the user can (and must) customize some of the configuration items from time to time. 

### Base IPI Installation

_under construction_

### Bring your own hosted zones

<pre><code>platform:
  gcp:
    publicDNSZone: &#9312
      id: &#9313;
      project: &#9314;
    privateDNSZone: &#9312
      project:&#9314;
</code></pre>

<pre><code>&#9312; Public/Private zone information.
&#9313; ID of a preconfigured public hosted zone. This hosted zone must have the same domain as the base domain in the install config.
&#9314; In the case for the public zone, this is where the preconfigured public zone exists. In the case for the private zone, this is the project where the zone will be created (by the installer).
</code></pre>

### Shared VPN IPI

A shared vpn installation requires a host project and a service project. What is the difference between a host and service project? The host project is the project hosting the vpc or network. The service project is the project where the majority of other resources will reside (ex: hosting zones).

#### Prerequisites

1. Create a public Zone in Service Project where the base domain matches the base domain in the install config.
2. Create Network (and subnets) in Host Project
3. Account Permissions


#### Install Configuration

The following is an example install configuration for GCP XPN IPI installations.

<pre><code>additionalTrustBundlePolicy: Proxyonly
apiVersion: v1
baseDomain: &#9312
credentialsMode: Passthrough &#9313;
featureSet: TechPreviewNoUpgrade &#9314;
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
  name: &#9315;
platform:
  gcp:
    projectID: &#9316;
    networkProjectID: &#9317;
    region: &#9318;
    network: &#9319;
    computeSubnet: &#9320;
    controlPlaneSubnet: &#9320;
publish: External
</code></pre>


<pre><code>&#9312; The base domain of the public zone in the service project.
&#9313; A successful GCP XPN IPI installation requires the credentials mode to be set to Passthrough.
&#9314; GCP Shared VPN IPI installations require the Tech Preview enabled tag because all features are currently not GA.
&#9315; Name of the cluster.
&#9316; Service Project ID.
&#9317; Host Project ID; the owner project of the VPC.
&#9318; Region where the project will be installed.
&#9319; The name of the network from the host project.
&#9320; The compute and control plane subnet(s) should as a resource under the network in GCP. These can be different subnets, but must both exist under the same network.
</code></pre>

### Private Cluster

To create a private cluster, a few components needs to be in place before the installation begins.

- VPC
- Subnets
- Cloud Router
- Cloud NAT

**Note**: _All of these resources must exist in the project where the cluster will be installed_.

<br>
If a VPC does _not_ exist, then create a VPC and name it whatever you choose. Ensure that a subnet is created for the region where you intend to install. The easiest method to complete this task is by selecting the option `Automatic` for `Subnet Creation Mode` when creating a VPC Network.
<br>
A Cloud Router resource must be created in the region that is intended for installation. A Cloud NAT resource must also be created and associated with the Cloud Router and VPC that were created in the previous steps.
<br>
The default install configuration file sets the following information:

```yaml
networking:
  clusterNetwork:
  - cidr: 10.128.0.0/14
    hostPrefix: 23
  machineNetwork:
  - cidr: 10.0.0.0/16
```

The machine network value must be altered to machine the value for the subnet with the matching region. For instance a subnet with the value `10.128.0.0/20` could have the cluster and machine network values adjusted similar to the snippet below. Notice that the cluster network value is adjusted as it was going to overlap with the machine network.

```yaml
networking:
  clusterNetwork:
  - cidr: 10.124.0.0/14
    hostPrefix: 23
  machineNetwork:
  - cidr: 10.128.0.0/16
```

**Note**: _The machine and cluster network cannot overlap_.
<br>

A problem still arises with private clusters; private clusters do not have access to the required data (urls) required for installation. To solve this issue, setup a VM in GCP. The new VM _should_ use the same network that the cluster is going to use. The VM acts as a bridge between the private cluster and the internet. Add the following information to the VM either during initialization or after creation:

- ssh keys
- GCP service account
- GCP credentials (osServiceAccount.json)
- installer executable (add to /usr/bin)
- secrets data for installation (secrets/pull-secrets.txt)


<br><br>

## UPI Installations

The UPI (user provisioned) installations are far more in depth and require a greater knowledge of clusters and their resources.

### Shared VPN UPI

This section is created to assist with installation during UPI for GCP with
a shared private virtual network or XPN.

#### Initialization

All steps in this section _should_ be completed **before** the installation occurs.

For the purpose of this example, the following projects were used:
- Host: openshift-dev-installer
- XPN: openshift-installer-shared-vpc

#### Account Access

You should have a service account in both the host and xpn projects. These service accounts should **NOT** be the same.

The service account access (roles) for the service project include:
- roles/compute.admin
- roles/compute.storageAdmin
- roles/deploymentmanager.editor
- roles/dns.admin
- roles/iam.securityAdmin
- roles/iam.serviceAccountAdmin
- roles/iam.serviceAccountKeyAdmin
- roles/iam.serviceAccountUser
- roles/storage.admin

The service account access (roles) for the host project include:
- roles/compute.admin
- roles/compute.loadBalancer.admin
- roles/dns.admin

**Note**: _The roles are subject to change_.
<br><br>
If you would like to see what account roles are attached to your accouunt for a project:

```bash
get-iam-policy {project} \
    --flatten="bindings[].members" \
    --format='table(bindings.role)' \
    --filter="bindings.members:{service-account}"
```

#### GCP Key configuration

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


#### Configuration through gcloud

Run `gcloud config list` to view the current region, account, and project. Run `gcloud config set {param} {value}` to set the correct
information. For the purposes of this example the following config is set:

```bash
[compute]
region = us-east1
zone = us-east1-b
[core]
account = XXXX-dev@openshift-installer-shared-vpc.iam.gserviceaccount.com
disable_usage_reporting = True
project = openshift-installer-shared-vpc
```

The `account` is the service account that you created for the XPN project.
The `project` is the name of the XPN project.
The `region` must be a valid region for the XPN project.

#### Creating the install-config

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
  name: ${USER}-dev-xpn
platform:
  gcp:
    projectID: openshift-installer-shared-vpc
    region: us-east1
publish: External
```

The `region` and `projectID` should match the values that were setup earlier. The `baseDomain` is selected
from the options that appear during provisioning.

**NOTE**: The user _must_ add the `credentialsMode: Passthrough` to the install-config _after_ the file has been created. 

#### Grabbing the correct files

Visit the [openshift-installer docs](https://github.com/openshift/installer/tree/master/upi/gcp) to get all of the python
scripts that you will need during the installation process.

The main scripts are located here:
- `GCP_UPI_SharedVCP.sh`: The main script for running the installation
- 'destroy.sh`: Destruction of _most_ artifacts created during installation

The name of the project and username in the `GCP_UPI_SharedVCP.sh` _must_ be adjusted.

### Running the Install

There are two different methods to run the install using the script provided. Those will be documented here.

#### Basic

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


#### Adjusting the script
- make the changes to the script to auto
<br><br>

### Destroying Resources

Run the [`GCP_Destroy.sh`](./scripts/GCP_Destroy.sh). The script will cleanup _most_ of the artifacts and resources created during the installation.

1. Go to GCP (online site) and destroy the remaining resources.
2. Select the host project (openshift-dev-installer).
3. Navigate to `Cloud DNS`. Search for your username (for me it was `${USER}`).
4. Go into the resources here, and first select all records and `Delete records`.
5. After all records have been deleted, you can delete the Zone.
6. Navigate to the public DNS records. Again search for your name. **DO NOT** Delete anyone elses records. **DO NOT** delete the public zone.
7. Navigate to Deployments, delete the deployments attached to your user **ONLY**.
<br><br>

## GCP Resource Manipulation

The following section is provided as a reference for manipulating GCP resources after the cluster is running.
<br><br>

### Adding Disks

The section will detail adding a disk to a cluster installed on GCP. You may use [this link](https://kubebyexample.com/en/concept/persistent-volumes)
for a simple example using kubernetes. 

1. Begin by installing a cluster using openshift-install; an IPI configuration.
2. You will be able to view all machines, and machinesets and other resources in OC

```bash
oc get machinesets -A
```

3. Using the web console, create a Persistent Volume Claim (PVC).
3.1 Using the output from the openshift-install create cluster, grab the username, password, and url.
3.2 Open the URL and enter the information.
3.3 Go to Storage -> Persistent Volume Claims
3.4 Create a new PVC. You should now see resource in `oc`

```bash
oc get pvc -A
```

```bash
NAME                           CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM   STORAGECLASS   REASON   AGE
PVC-VOLUME-NAME                5Gi        RWO            Retain           Available           slow                    35m
```

```bash
NAME                                  STATUS    VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS   AGE
PVC-VOLUME-NAME                       Pending                                      standard       28m
```

3.5 As above, you will notice that the PVC is `pending`. If you look at the websole where the
PVC was created and look at the `EVENTS`, it will say that a consumer is required before it can be configured.

4. Let's make a fake consumer

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pv-deploy
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mypv
  template:
    metadata:
      labels:
        app: mypv
    spec:
      containers:
      - name: shell
        image: centos:7
        command:
        - "bin/bash"
        - "-c"
        - "sleep 10000"
        volumeMounts:
        - name: mypd
          mountPath: "/tmp/persistent"
      volumes:
      - name: mypd
        persistentVolumeClaim:
          claimName: PVC-VOLUME-NAME
```

Output the above into a file called deploy.yaml

5. Run `oc apply -f deploy.yaml`.
6. If you rerun the `oc get` you will see a `Bound` instead of `Pending`.
7. Visit GCP -> Disks, and you will see the new disk created. 

<br><br>

## GCloud CLI Authentication

The installer can use the gcloud credentials for authentication. In order to do this the profile must be signed in to prior to installation. Set the default login information:

```bash
export GOOGLE_APPLICATION_CREDENTIALS=$HOME/.gcp/<Path-To-Profile>.json
```

Then log in via gcloud:

```bash
gcloud auth application-default login
```

## Troubleshooting

### Failure During Kube API
<br>
The following errors (or similar) may be seen:
<br><br>

#### Kube API Timeout

```
DEBUG Still waiting for the Kubernetes API: Get "https://api.${USER}-xpn.installer.gcpxpn.devcluster.openshift.com:6443/version": dial tcp 35.227.103.128:6443: i/o timeout
```

This is an indicator that the ignition is not able to be fetched. Confirm this checking the log bundle in the directory `serial`. Search for the text `fetch` in the bootstrap node log file. This will confirm that the ignition was unable to be fetched if there are errors surrounding this text.

Check the `boostrap/journals/bootkube.log` file.
<br><br>
If you see the error `Error: unknown flag: --feature-set`, this means that the Release image may be out of date. Check the environment variable `OPENSHIFT_INSTALL_RELEASE_IMAGE_OVERRIDE`, and it may reveal an out of date release.

**Note**: _It is possible that the release version needs to be bumped forcefully. For example the release may be 4.12, but the current version is 4.13 (auto bump it)._
<br><br>

#### Kube API unreachable

_under construction_

### Investigate gcp resource errors

Errors reported with the following text should be investigated further in the GCP Console. Quotas are project level and can provide more information about errors at the project level. The Log Explorer can be used to view issues/errors at the resource level. See more information [here](https://cloud.google.com/compute/docs/troubleshooting/troubleshooting-resource-availability).

- ZONE_RESOURCE_POOL_EXHAUSTED
- ZONE_RESOURCE_POOL_EXHAUSTED_WITH_DETAILS
