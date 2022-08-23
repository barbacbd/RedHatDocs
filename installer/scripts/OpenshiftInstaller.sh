#!/bin/bash

COLOR_OFF='\033[0m'
BLUE='\033[0;34m'

function INFO() {
    echo -e "${BLUE}${1}${COLOR_OFF}"
}

# make the assets directory if it does not exist
if [ ! -d "assets" ]; then
    INFO "Creating assets dir ...";
    mkdir assets;
fi

# copy the install config over in case you have one.
if [ -f "install-config.yaml" ]; then
    INFO "Copying install-config.yaml to assets ...";
    cp install-config.yaml assets/
fi

INFO "Pushing assets on to stack ...";
pushd assets

if [[ -z "${OPENSHIFT_INSTALL_RELEASE_IMAGE_OVERRIDE}" ]]; then
    DEFAULT_RELEASE="$(openshift-install version | grep 'release image ' | cut -d ' ' -f3 | cut -d ':' -f 2)"
    echo "DEFAULT_RELEASE=${DEFAULT_RELEASE}"
    RELEASE="${OPENSHIFT_RELEASE:-${DEFAULT_RELEASE}}"
    export OPENSHIFT_INSTALL_RELEASE_IMAGE_OVERRIDE="registry.ci.openshift.org/ocp/release:${RELEASE}"
fi

INFO "OPENSHIFT_INSTALL_RELEASE_IMAGE_OVERRIDE=${OPENSHIFT_INSTALL_RELEASE_IMAGE_OVERRIDE}"

# Requires openshift-install in your path
openshift-install create cluster

INFO "Popping assets from the stack ...";
popd
