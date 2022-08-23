#!/bin/bash

# If the user would like to skip the questions they may provide the
# version as argument #1

version=""
bindir=/home/$USER/bin

if [ $# -ge 1 ]; then
    version=$1
fi

if [ $# -ge 2 ]; then
    bindir=$2
fi

if [ "$version" == "" ]; then
    while true; do
	read -p "Would you like to pull the latest [y/N]? " use_latest
	case $use_latest in
	    [Yy]* ) version="latest"; break;;
	    [Nn]* )
		read -p "What oc version would you like? " version;
		break;;
	    * ) echo "Please answer yes or no.";;
	esac
    done
fi

mkdir installer_puller_tmp;
pushd installer_puller_tmp;
wget https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/$version/openshift-install-linux.tar.gz;
tar -xvzf openshift-install-linux.tar.gz;

# get the version, this will handle the case of 'latest' too
retrieved_version=$(./openshift-install version | head -n 1 | awk '{print $2}')

# rename the OC with the version 
mv openshift-install openshift-install-$retrieved_version

mv openshift-install-$retrieved_version $bindir
pushd $bindir


if [ -f openshift-install ]; then
    # unlink any current installer symlink
    if [ -L openshift-install ]; then
	unlink openshift-install
    else
	# remove if it is not a symlink
	rm -rf openshift-install
    fi
fi

# create a symlink to the retreived version of installer
ln -s openshift-install-$retrieved_version openshift-install

# go back to where we were 
popd
popd

# remove the dir that we created
rm -rf installer_puller_tmp
