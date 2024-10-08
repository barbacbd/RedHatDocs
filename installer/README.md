# Table of Contents

- [gcp](./gcp) - Directory containing information for installer gp clusters.
- [scripts](./scripts) - Directory containing general installer scripts.
- [secrets](./secrets) - Directory containing information relavant to obtaining and using pull secrets for the installer.
- This directory contains the information and scripts to generate a docker/podman image for the installer.

# Instructions and Notes for Creating a cluster with Openshift Installer

This document will include the information for utilizing openshift-installer to create a cluster. This tool
is used to create a Docker image and create/install a cluster using openshift-installer.

# Related Projects

See the following Projects for references that will be mentioned throughout this document:

- [Pull Secrets](https://github.com/barbacbd/RedHatDocs/blob/main/installer/secrets/README.md)
- [Openshift Installer](https://github.com/openshift/installer)

# Creating a cluster

To reate a cluster using openshift-installer run the following command:

```bash
cd /path/to/installer/;

hack/build.sh;

bin/openshift-installer create cluster

```

This process will start by asking for some information that will be generated in the `install-config.yaml`.
Then the process of installing will begin.

## Common Build Args

`MAKEFLAGS=-j12 MODE=dev TAGS="release" ./hack/build.sh`

- `-j12`: Build with 12 threads.
- `MODE=dev`: Debug build environment.
- `TAGS="release"`: Release build, required to set into debug mode.


# Accessing the cluster

The end of the installation will provide information about entering the cluster:

```
INFO Login to the console with user: "{{ kube_username }}", and password: "{{ password }}"
```

Before entering the cluster, the `oc` executable must be installed:

```bash

wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz

tar -xvzf openshift-client-linux.tar.gz
```

This will produce the `oc` executable (as well as another). Move the executable(s) to `/usr/bin` or `/usr/local/bin` so they are in `$PATH`.

# Installer Container Documentation

The Dockerfile should be executed from the /home/$USER directory. 

```bash
cd ~/ && docker build -t installer -f /path/to/this/Dockerfile .
```

To run and login to the container:

```bash
docker run -it installer:latest /bin/bash
```

# YAML Configuration

The following parameters are required in the yaml file as inputs to the install-config template:
- platform - cloud platform
- region - region for the platform (these may be similar between platforms, but are specific)
- base_domain - domain for the cluster
- secrets_file - File where the secrets information is stored, please [read](https://github.com/barbacbd/RedHatDocs/blob/main/installer/secrets/README.md) for more information.
- ssh_key_file - File where the ssh key is stored (usually in ~/.ssh)

The following parameters are required for the rest of the configuration process:
- docker
  - image_name: name of the local image when using `podman image ls`
  - iamge_tag: tag for the image (usually `latest`)

The following are optional parameters for the configuration process:
- env - Any parameters added here are in the (key,value) pair format formatted in the file like:
```
env:
  key: value
```
The following is the same as `export key=value`


# Supported Platforms

- aws
- gcp
- azure

# OC References

Downloads can be found [here](https://amd64.ocp.releases.ci.openshift.org/).


# Version control openshift client [OPTIONAL]

Move the openshift client (oc) and openshift installer to your path. For instance:

```bash
mv oc oc-<version>
mv oc-<version> /home/$USER/bin

cd /home/$USER/bin

ln -s oc-<version> oc
```

Now `oc` will be the version that you want it to be.


# Extra installation notes

When installing a cluster from the latest `master/main` branch, export an environment variable to override the release image.

```bash
export OPENSHIFT_INSTALL_RELEASE_IMAGE_OVERRIDE={ release-image }
openshift-install create cluster
```

The release-image can be found [here](https://amd64.ocp.releases.ci.openshift.org/). Look at the top of the web page for the image name.
Generally the line will include `oc adm release extract`, but you only need the image link at the tail end of the line.


If you would like to create a bastion host to reach the rest of the cluster [follow these directions](https://github.com/eparis/ssh-bastion). Do _NOT_ skip the steps for passing your ssh credentials to the other nodes in the cluster or you will not be able to ssh from the bastion to other nodes.

## SSH to Nodes

During installs the bootstrap node may not have the ssh information to create/allow a connection to another node (ex: bootstrap node direct ssh to a control plane node).

```bash
ssh -A -J <bootstrap-user>@<bootstrap-ip> <control-plane-user>@<control-plane-internal-ip>
```

_NOTE_: The bootstrap defaults to being cleaned up after the bootstrap process is complete. There are ways to keep the node around.
