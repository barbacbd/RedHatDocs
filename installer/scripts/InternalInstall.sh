#!/bin/bash

COLOR_OFF='\033[0m'
BLUE='\033[0;34m'

PLATFORM="GCP"
LOWER_PLATFORM=`echo ${PLATFORM,,}`


function INFO() {
    echo -e "${BLUE}${1}${COLOR_OFF}"
}

ftime=`stat -c %Y ~/secrets/pull-secrets.txt`
ctime=`date +%s`
diff=$(( (ctime - ftime) / 86400 ))
INFO "Pull secret is ${diff} days old"

if [ "$diff" -lt "20" ]; then
    INFO "Pull Secret is in good shape"
elif [ "$diff" -lt "30" ]; then
    INFO "Pull Secret will expire soon"
else
    INFO "Pull Secret is expired"
    exit 1
fi


curDir=${PWD##*/}
curDir=${curDir:-/}
echo $curDir
if [ $curDir == "assets" ]; then
    INFO "assets exists, skipping ..."
else
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
fi

python3 -c '
import yaml;
path = "install-config.yaml";
data = yaml.safe_load(open(path));
data["publish"] = "Internal";
open(path, "w").write(yaml.dump(data, default_flow_style=False))
'

openshift-install create manifests --log-level=DEBUG

python3 -c '
import yaml;
import sys;

path = "manifests/cluster-ingress-default-ingresscontroller.yaml";
data = yaml.safe_load(open(path));
data["spec"]["endpointPublishingStrategy"]["loadBalancer"]["providerParameters"] = {
    sys.argv[1]: {
        "clientAccess": "Global"
    },
    "type": sys.argv[2]
}
open(path, "w").write(yaml.dump(data, default_flow_style=False))
' ${LOWER_PLATFORM} ${PLATFORM}

exit 1

if [[ -z "${OPENSHIFT_INSTALL_RELEASE_IMAGE_OVERRIDE}" ]]; then
    DEFAULT_RELEASE="$(openshift-install version | grep 'release image ' | cut -d ' ' -f3 | cut -d ':' -f 2)"
    echo "DEFAULT_RELEASE=${DEFAULT_RELEASE}"
    RELEASE="${OPENSHIFT_RELEASE:-${DEFAULT_RELEASE}}"
    export OPENSHIFT_INSTALL_RELEASE_IMAGE_OVERRIDE="registry.ci.openshift.org/ocp/release:${RELEASE}"
fi

INFO "OPENSHIFT_INSTALL_RELEASE_IMAGE_OVERRIDE=${OPENSHIFT_INSTALL_RELEASE_IMAGE_OVERRIDE}"

# Requires openshift-install in your path
openshift-install create cluster --log-level=DEBUG

