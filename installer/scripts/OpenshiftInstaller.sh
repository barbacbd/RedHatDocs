#!/bin/bash

COLOR_OFF='\033[0m'
BLUE='\033[0;34m'

function INFO() {
    echo -e "${BLUE}${1}${COLOR_OFF}"
}

# Return 1 or true when the platform specified in the first argument
# matches the platform found in the install-config.
function ComparePlatforms() {
    platform=$1
    filename=$2

    pyOutput=$((python3 -c '\
from yaml import safe_load;
import sys;

platform = sys.argv[1];
filename = sys.argv[2];

with open(filename, "r") as yamlFile:
    data = safe_load(yamlFile.read())

if "platform" in data:
    print(int(platform in data["platform"]))
else:
    print(0)' $platform $filename) 2>&1)

    echo "${pyOutput}"
}

function FindAndConvertConfig() {
    platform=$1

    if [ ! -f "install-config.yaml" ]; then
	if [ -f "install-config.yaml.${platform}" ]; then
	    cp "install-config.yaml.${platform}" "install-config.yaml"
	    return 1 # no error
	fi
    else
	# determine if the the platform is the same in the install config as
	# the platform that is specified
	ComparePlatforms $platform "install-config.yaml"
	compared=$?
	if [[ $compared -lt 1 ]]; then
	    # error occurred curing the compare platforms
	    return 0
	fi
	
	return 1 # no error, config exists
    fi
    # Error - but ignore. Only error when the platforms do not match.
    # This will not error, because this will just cause the installer
    # to ask the user to create a new install config during the process.
    # This is intended behavior.
    return 1
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

# set default values
: ${platform:=aws}

while getopts p: flag
do
    case "${flag}" in
	p) platform=${OPTARG};;
    esac
done

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

FindAndConvertConfig $platform
conversionOutput=$?

# check if install config exists
if [[ $conversionOutput -lt 1 ]]; then
    INFO "failed to find and convert the install config into a valid configuration file."
    exit
fi

if [[ -z "${OPENSHIFT_INSTALL_RELEASE_IMAGE_OVERRIDE}" ]]; then
    DEFAULT_RELEASE="$(openshift-install version | grep 'release image ' | cut -d ' ' -f3 | cut -d ':' -f 2)"
    echo "DEFAULT_RELEASE=${DEFAULT_RELEASE}"
    RELEASE="${OPENSHIFT_RELEASE:-${DEFAULT_RELEASE}}"
    export OPENSHIFT_INSTALL_RELEASE_IMAGE_OVERRIDE="registry.ci.openshift.org/ocp/release:${RELEASE}"
fi

INFO "OPENSHIFT_INSTALL_RELEASE_IMAGE_OVERRIDE=${OPENSHIFT_INSTALL_RELEASE_IMAGE_OVERRIDE}"

# Requires openshift-install in your path
openshift-install create cluster --log-level=DEBUG

