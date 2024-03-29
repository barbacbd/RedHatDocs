#!/bin/bash
# This script is used to configure the data before the Dockerfile is run
# so that all of the correct and available information is present on the
# image. If the following information is available, the data will be
# added to the root directory and ultimately moved to the image:
# - /home/${USER}/.ssh                  -> /root/.ssh
# - /home/${USER}/.aws                  -> /root/.aws
# - /home/${USER}/.azure                -> /root/.azure
# - /home/${USER}/.gcp                  -> /root/.gcp
#
# The following information is added to the the image if present, but
# this data changes often this is a WARNING that the user will want
# to be sure that the data is up to date:
# - /home/${USER}/.docker/config.json   -> /root/.docker/
# - /home/${USER}/bin/openshift-install -> /usr/bin

if [ "${PWD}" == "/" ]; then
    echo "ERROR: Do not run from the root directory: /"
    exit 1
fi

if [ -d "root" ]; then
    echo "WARNING: Removing all previous data from root"
    rm -rf root
fi
# this is the directory where all data will be stored
mkdir root
pushd root # push the directory to the stack

# grab all platform configuration information (if exists)
platforms=("aws" "azure" "gcp")
for platform in "${platforms[@]}"; do
    platform_location="/home/${USER}/.${platform}"

    if [ -d $platform_location ]; then
	cp -R $platform_location .
    fi
done

# copy over all ssh keys
if [ -d "/home/${USER}/.ssh" ]; then
    cp -R /home/${USER}/.ssh .
fi

# Get the configuration or secret key information for creating a
# cluster with the openshift installer
if [ -d "/home/${USER}/.docker" ]; then
    cp -R /home/${USER}/.docker .
fi

popd # back to reality

if [ -d "usr" ]; then
    echo "WARNING: Removing all previous data from usr"
    rm -rf usr
fi
# this is the directory where the executable will be stored
mkdir -p usr/bin
if [ -f "/home/${USER}/bin/openshift-install" ]; then
    cp "/home/${USER}/bin/openshift-install" usr/bin/
else
    if [ -f "/usr/bin/openshift-install" ]; then
	cp "/usr/bin/openshift-install" usr/bin/
    fi
fi
