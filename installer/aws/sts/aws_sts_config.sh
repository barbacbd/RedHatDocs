#!/bin/bash
#######################################################################
# This script is created as a configuration tool for installations
# to AWS utilizing the Security Token Service (sts).
# To find more information about the installation process see:
# https://docs.openshift.com/container-platform/latest/authentication/managing_cloud_provider_credentials/cco-mode-sts.html
#######################################################################

COLOR_OFF='\033[0m'
GREEN='\033[0;32m'
function DEBUG() {
    echo -e "${GREEN}[${FUNCNAME[0]}]: ${1}${COLOR_OFF}"
}


set -eux

#######################################################################
# Before executing this script, the user should verify that the
# region where the cluster will be installed can handle the STS
# regional endpoint (all regions have one, but it must be active).
# Go to the aws web console -> IAM - > Account Settings
# scroll down to the `Endpoints` Section and ensure that the region
# is activated.
#######################################################################


# variables used in this script
secretsFile=~/.docker/config.json
configUser="bbarbach"
awsRegion="us-east-2"
outputDir="."
credsDir="."
releasePath="openshift-release-dev"
releaseVersion="4.11.0-rc.6-x86_64"
ocImage="quay.io/${releasePath}/ocp-release:${releaseVersion}"

DEBUG "secretsFile=$secretsFile"
DEBUG "configUser=$configUser"
DEBUG "awsRegion=$awsRegion"
DEBUG "outputDir=$outputDir"
DEBUG "releasePath=$releasePath"
DEBUG "releaseVersion=$releaseVersion"
DEBUG "ocImage=$ocImage"

# use the same image for the installer as ccoctl
DEBUG "Setting OPENSHIFT_INSTALL_RELEASE_IMAGE_OVERRIDE=$ocImage ..."
export OPENSHIFT_INSTALL_RELEASE_IMAGE_OVERRIDE=$ocImage


CCO_IMAGE=$(oc adm release info --image-for='cloud-credential-operator' $ocImage)
oc image extract $CCO_IMAGE --file="/usr/bin/ccoctl" -a $secretsFile
chmod 775 ccoctl
# Assumes that ~/bin is in your PATH
mv ccoctl ~/bin

# Extract the list of CredentialsRequest objects from the OpenShift Container Platform release image
oc adm release extract --credentials-requests --cloud=aws --to=$credsDir $ocImage

DEBUG "Current directory structure ..."
tree .

#######################################################################
# Use the ccoctl tool to process all CredentialsRequest objects in the
# credrequests directory. This will create a bucket in aws::S3 named
# ${configUser}-ccoctl-oidc. The below command will also create/update
# the IAM roles for the user.
#
# IMPORTANT: If you have already run this command and you no longer
# have the manifests in /manifests please look in
# ccoctl_manifests_archive. The tree command is here to provide output
# as to what is currently in the manifests directory.
# You should see something like:
# -rw-------. 1 <user> <user> 161 Apr 13 11:42 cluster-authentication-02-config.yaml
# -rw-------. 1 <user> <user> 379 Apr 13 11:59 openshift-cloud-credential-operator-cloud-credential-operator-iam-ro-creds-credentials.yaml
# -rw-------. 1 <user> <user> 353 Apr 13 11:59 openshift-cluster-csi-drivers-ebs-cloud-credentials-credentials.yaml
# -rw-------. 1 <user> <user> 355 Apr 13 11:59 openshift-image-registry-installer-cloud-credentials-credentials.yaml
# -rw-------. 1 <user> <user> 339 Apr 13 11:59 openshift-ingress-operator-cloud-credentials-credentials.yaml
# -rw-------. 1 <user> <user> 337 Apr 13 11:59 openshift-machine-api-aws-cloud-credentials-credentials.yaml
#
# If you do not see these files, then your IAM role currently exists
# and a new set of files will not be generated for you. If you KNOW
# that the archive directory contains the correct files, copy those
# files into manifests. If you are unsure or hesitent, you may delete
# the IAM role from the AWS web console.
#######################################################################
ccoctl aws create-all --name="${configUser}-ccoctl" --region=$awsRegion --credentials-requests-dir=$credsDir

DEBUG "Archiving files in manifests to ccoctl_manifests_archive ..."
cp -R manifests ccoctl_manifests_archive

DEBUG "Current directory structure ..."
tree .

# This install-config should be auto generated from the manifests that current exist
openshift-install create install-config --dir $outputDir

#######################################################################
# This installation method requires a tag of Manual. There are
# several other supported modes for STS installations.
# open the install-config and force the credentialsMode to Manual
#######################################################################
DEBUG "Modifying the install config, setting credentialsMode to Manual ..."
python3 -c '
import yaml;
import sys;
path = "".join(sys.argv[1:]) + "/install-config.yaml";
data = yaml.safe_load(open(path));
data["credentialsMode"] = "Manual";
open(path, "w").write(yaml.dump(data, default_flow_style=False))' $outputDir

# Create the manifests and copy over all created by ccoctl to the same directory
openshift-install create manifests --dir $outputDir

# Copy the private key that the ccoctl generated in the tls directory to the installation directory
if [ "$outputDir" != "." ]; then
    WARN "Copying tls to $outputDir, not sure if this is needed ..."
    cp -R tls $outputDir/
fi

DEBUG "Current directory structure ..."
tree .

# run the installer
openshift-install create cluster --dir $outputDir --log-level=DEBUG
