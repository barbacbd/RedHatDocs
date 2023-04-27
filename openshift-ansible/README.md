# Instructions and Notes for Installing and using Openshift Ansible

This document will include information for utilizing openshift-ansible and openshift installer to create a cluster.
Throughout the document, AWS will be the platform of choice.

# Related Projects

See the following Projects for references that will be mentioned throughout this document:

- [Pull Secrets](https://github.com/barbacbd/tools/blob/main/references/PullSecret.md)
- [OA-Testing](https://github.com/mtnbikenc/oa-testing) - Utilities to install clusters to aws utilizing openshift-ansible
- [OI-Dev](https://github.com/jstuever/oi-dev) - Simpler cluster installation utilizing openshift-ansible
- [Openshift Installer](https://github.com/openshift/installer)
- [Openshift Ansible](https://github.com/openshift/openshift-ansible)
- [openshift-ansible-assistant](https://github.com/barbacbd/openshift-ansible-assistant)

# Supported Platforms

- AWS

# Future Supported Platforms

- Azure
- GCP

# Prerequisites 

## Make a directory called `assets` in `oi-dev`

The assets directory is the default where the installation should occur for the `oi-dev` project to utilize openshift-installer information.

<br>

## Ensure that an ssh key `oi` exists.

There should be a matching public key called `oi.pub`. It is ok to **copy** the
ssh key that you normally use. DO NOT sim-link the keys as this could create issues if you
ever remove the keys or change them.

**Note**: _If the key in OI is the same as the one used for the openshift installer create cluster, then this process will go smoother_. 

<br>

## Create a template for the install-config (optional)

```
apiVersion: v1
baseDomain: devcluster.openshift.com
metadata:
  name: {{ CLUSTER NAME }}
platform:
  {{ PLATFORM }}:
    region: {{ REGION }}
```

<br>

## Add the openshift-installer bin to the path [OPTIONAL]

`export PATH=/path/to/installer/bin:$PATH`

For me this would include

`export PATH=$HOME/dev/installer/bin:$PATH`

The version controlled way to do this (when you want to include multiple versions of the installer) is:

```bash
mv /path/to/installer/bin/openshift-installer /home/$USER/bin
```

This makes the assumption that `/home/$USER/bin` is in your path.

<br>

## Setting up the environment

**Note:** _Using `ansible==2.9.27` failed. Remove this from the computer (at least for now)_.

Install `libselinux-python3` via yum. This will be picked up as a pip package that you can see as version (>=2.9) via pip3 list. **If you install directly with pip, the version is VERY different.**

Create a virtual environment for python3

```
python3.9 -m venv ansible-venv --system-site-packages

pip install pip --upgrade

pip install ansible-core boto3
```

**Note**: _As of December 2022, `ansible-core` (2.13.x) should be installed instead of `ansible-base`. Ansible-Core can only be installed with python3.9+_.

<br>

## Platform Specific

### AWS

The region that will be used for installation _should_ have an EC2 Key Pair with the name matching the username for the computer where the installation originated. _This can be altered, but the defaults of the oi-dev project use the username._


# Create a cluster using openshift-installer or using the oi.sh script

```bash
cd /oi-dev
mkdir assets
scripts/oi.sh create cluster
```

# Run the playbooks/tasks for openshift ansible

## Create the bastion

The bastion was/is a defense mechanism that provides a link or connection to the cluster. An `ssh pod` or bastion is installed
in the cluster so that we can reach the cluster through this pod. It provides a connection to the cluster but access must be
achieved indirectly.

To create the bastion execute the command:

```bash
scripts/oi-byoh.sh bastion
```

There should be a file `./assets/byoh/bastion`. The file will contain the bastion host.

You may also verify that the bastion was created with

```bash
oc get service -n test-ssh-bastion ssh-bastion -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

**Note**: _replace hostname with ip for azure and gcp_.

```bash
export KUBECONFIG=assets/auth/kubeconfig
oc get service -n test-ssh-bastion
```

<br>

## Create the machinesets

To create the machinesets run the command

```bash
scripts/oi-byoh.sh create
```

You can verify that the machinesets have been created with `oc`.

```bash
export KUBECONFIG=assets/auth/kubeconfig
oc get machinesets -A
```

You should see new `RHEL` machinesets.

<br>

## Prepare the machines 

```bash
scripts/oi-byoh.sh prepare
```

<br>

## Bring up all of the RHEL nodes

To bring up the rhel nodes and ensure all necessary packages are installed and up to date run the following command:

```bash
scripts/oi-byoh.sh scaleup
```
<br>

## Upgrades

```bash
scripts/oi-byoh.sh upgrade
```

All tests should also run the upgrade to ensure that they pass.

<br>

## SSH to the RHEL Node(s)

```
ssh -o IdentityFile=~/.ssh/oi -o StrictHostKeyChecking=no core@$(<assets/byoh/bastion)
```

The above command will get you to the bastion.

To ssh to the other nodes using the Bastion has a hopping point, look for the hosts in `assets/byoh/hosts`

```
scripts/oi-byoh.sh ssh ec2-user@<host from hosts file>
```

**Note:** The user above was `ec2-user`, please make sure that this remains!

<br>

# FAQ

## Openshift Installer vs Openshift Ansible

Openshift Ansible is generally related to ansible and talked about with versions 3.x. In the past, RHEL nodes were used. After
the acquisition of the product RHCOS, ansible was migrated. There is still a need to install RHEL nodes, and thus openshift
ansible was kept alive and used as a bridge with openshift installer to allow the users to spin up RHEL nodes. The openshift
installer will only utilize RHCOS nodes (which do not have saved state) unless openshift ansible is used after a cluster is
created.

<br>

## Error - Cannot run ansible playbook

If you used a venv and it is **NOT** sourced, or if ansible is not installed the following error could
appear during `oi-byoh.sh create`:

```bash
$ scripts/oi-byoh.sh create
time: cannot run ansible-playbook: No such file or directory
Command exited with non-zero status 127
0.00user 0.00system 0:00.00elapsed 82%CPU (0avgtext+0avgdata 860maxresident)k
0inputs+0outputs (0major+22minor)pagefaults 0swaps
```

**Note:**: _All ansible logs are wrapped in `time:` when using `oi-dev`_.


# OC Commands

## Checking machines and machinesets

**Note:** _`--all_namespaces` and `-A` are the same_.

```
oc get machinesets -A
```

_When running a normal openshift-install the command will only show nodes without the name RHEL in them. During an install with openshift ansible
the machine sets will contain the machinesets for RHEL workers. You will see names ****-RHEL-***._

```
oc get machines -A
```

_When running a normal openshift-install the command will only show nodes without the name RHEL in them. During an install with openshift ansible
the machines will contain the machines for RHEL workers. You will see names ****-RHEL-***._

_If you are running these steps immediately after the `CREATE` script, then you will notice that the machines are `provisioned` but **Note** `running`._

<br>

## Delete Machines(ets)

If you had a failure occur during the process, you may want to cleanup the machines before retrying.

```
oc delete machinesets -n {{ namespace }} {{ machine_name }}
```

You will see it say `deleting`, after that is completed (usualy takes 1-2 minutes). You are able to rerun the commands.

<br>

# Cleanup/Destroy clusters that are no longer on your local system

Create metadata.json with the following information:

```
{"clusterName":{{ CLUSTER_NAME }},"infraID": {{ CLUSTER_INFRA_ID }}, {{ PLATFORM }}:{"region": {{ REGION }}, "identifier":[{"kubernetes.io/cluster/{{ CLUSTER_INFRA_ID }}":"owned"}]}}
```

- You can find the cluster name (`CLUSTER_NAME`) on the platform where the cluster was installed.
- You can find the cluster infra-id (`CLUSTER_INFRA_ID`) on the platform where the cluster was installed.