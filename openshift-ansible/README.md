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

# Supported Platforms

- AWS

# Process

1. Make a directory called `assets` in `oi-dev`

The assets directory is the default where the installation should occur for the `oi-dev` project to utilize openshift-installer information.
<br>

2. Ensure that there is an ssh key called `oi`.

There should be a matching public key called `oi.pub`. It is ok to **copy** the
ssh key that you normally use. DO NOT sim-link the keys as this could create issues if you
ever remove the keys or change them.

**Note**: _If the key in OI is the same as the one used for the openshift installer create cluster, then this process will go smoother_. 

<br>

3. Create a cluster using openshift-installer or using the oi.sh script

- Option 1

```bash
cd /path/to/installer/;

hack/build.sh;

bin/openshift-installer create cluster --dir /path/to/assets

```

Go through the process of creating a cluster for AWS.

- Option 2

```
mkdir ~/oi
mkdir {{ PLATFORM }}
```

Create a template for the install-config

```
apiVersion: v1
baseDomain: devcluster.openshift.com
metadata:
  name: {{ CLUSTER NAME }}
platform:
  {{ PLATFORM }}:
    region: {{ REGION }}
```

Move to the oi-dev directory and run `scripts/oi.sh`.
<br>

4. Add the openshift-installer bin to the path [OPTIONAL]

`export PATH=/path/to/installer/bin:$PATH`

For me this would include

`export PATH=$HOME/dev/installer/bin:$PATH`

The version controlled way to do this (when you want to include multiple versions of the installer) is:

```bash
mv /path/to/installer/bin/openshift-installer /home/$USER/bin
```

This makes the assumption that `/home/$USER/bin` is in your path.


5. Version control openshift client [OPTIONAL]

Similar to step 4 (above), oc or the openshift client software can be version controlled by
moving the file to `/home/$USER/bin`. From this directory we can rename the `oc` with a version
for instance:

```bash
mv oc oc-<version>
mv oc-<version> /home/$USER/bin

cd /home/$USER/bin

ln -s oc-<version> oc
```

Now `oc` will be the version that you want it to be.


6. Setting up the environment

**Note:** _Using `ansible==2.9.27` failed. Remove this from the computer (at least for now)_.

Install `libselinux-python3` via yum. This will be picked up as a pip package that you can see as version (>=2.9) via pip3 list. **If you install directly with pip, the version is VERY different.**

Create a virtual environment for python3

```
python3.9 -m venv ansible-venv --system-site-packages

pip install pip --upgrade

pip install ansible-core boto3
```

**Note**: _As of December 2022, `ansible-core` (2.13.x) should be installed instead of `ansible-base`. Ansible-Core can only be installed with python3.9+_.


7. Run the commands to setup openshift ansible

```
scripts/oi-byoh.sh bastion
scripts/oi-byoh.sh create
scripts/oi-byoh.sh prepare
scripts/oi-byoh.sh upscale
```

# FAQ

1. What is a bastion?

The bastion was/is a defense mechanism that provides a link or connection to the cluster. An `ssh pod` or bastion is installed
in the cluster so that we can reach the cluster through this pod. It provides a connection to the cluster but access must be
achieved indirectly.

Checking that the bastion was created ...

There should be a file `./assets/byoh/bastion`. The file will contain the bastion host.

You may also verify that the bastion was created with

```
oc get service -n test-ssh-bastion ssh-bastion -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

The name _should_ match that of the host in `./assets/byoh/bastion`.

2. Openshift Installer vs Openshift Ansible

Openshift Ansible is generally related to ansible and talked about with versions 3.x. In the past, RHEL nodes were used. After
the acquisition of the product RHCOS, ansible was migrated. There is still a need to install RHEL nodes, and thus openshift
ansible was kept alive and used as a bridge with openshift installer to allow the users to spin up RHEL nodes. The openshift
installer will only utilize RHCOS nodes (which do not have saved state) unless openshift ansible is used after a cluster is
created.

3. Don't forget to destroy your cluster when finished !

4. AWS key issues

Go to AWS site, and create new keys or match the keys for each region. If you decide to install to a different region, then that region needs to have a matching key. **You can name the keys the same between regions.**

5. Testing SSH

```
ssh -o IdentityFile=~/.ssh/oi -o StrictHostKeyChecking=no core@$(<assets/byoh/bastion)
```

The above command will get you to the bastion.

To ssh to the other nodes using the Bastion has a hopping point, look for the hosts in `assets/byoh/hosts`

```
scripts/oi-byoh.sh ssh ec2-user@<host from hosts file>
```

**Note:** The user above was `ec2-user`, please make sure that this remains!


6. Does not know about ansible

If you used a venv and it is **NOT** sourced, or if ansible is not installed the following error could
appear during `oi-byoh.sh create`:

```
$ scripts/oi-byoh.sh create
time: cannot run ansible-playbook: No such file or directory
Command exited with non-zero status 127
0.00user 0.00system 0:00.00elapsed 82%CPU (0avgtext+0avgdata 860maxresident)k
0inputs+0outputs (0major+22minor)pagefaults 0swaps
```

**Note:**: _All ansible logs are wrapped in `time:` when using `oi-dev`_.


# OC Commands

## Bastion Lookup

```
oc get service -n test-ssh-bastion ssh-bastion -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

```
oc get service -n test-ssh-bastion
```

See #5 in FAQ about ssh to the bastion. 

**Note:**: _The username is core_.


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


## Delete Machines(ets)

If you had a failure occur during the process, you may want to cleanup the machines before retrying.

```
oc delete machinesets -n {{ namespace }} {{ machine_name }}
```

You will see it say `deleting`, after that is completed (usualy takes 1-2 minutes). You are able to rerun the commands.


# Cleanup/Destroy clusters that are no longer on your local system

Create metadata.json with the following information:

```
{"clusterName":{{ CLUSTER_NAME }},"infraID": {{ CLUSTER_INFRA_ID }}, {{ PLATFORM }}:{"region": {{ REGION }}, "identifier":[{"kubernetes.io/cluster/{{ CLUSTER_INFRA_ID }}":"owned"}]}}
```

- You can find the cluster name (`CLUSTER_NAME`) on the platform where the cluster was installed.
- You can find the cluster infra-id (`CLUSTER_INFRA_ID`) on the platform where the cluster was installed.