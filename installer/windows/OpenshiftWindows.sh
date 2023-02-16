#!/bin/bash

# Grab a release image based on the current build
if [[ -z "${OPENSHIFT_INSTALL_RELEASE_IMAGE_OVERRIDE}" ]]; then
    DEFAULT_RELEASE="$(openshift-install version | grep 'release image ' | cut -d ' ' -f3 | cut -d ':' -f 2)"
    echo "DEFAULT_RELEASE=${DEFAULT_RELEASE}"
    RELEASE="${OPENSHIFT_RELEASE:-${DEFAULT_RELEASE}}"
    export OPENSHIFT_INSTALL_RELEASE_IMAGE_OVERRIDE="registry.ci.openshift.org/ocp/release:${RELEASE}"
fi

function InstallConfig() {
# Create the install config and manifests
    openshift-install create install-config --log-level=DEBUG

    python3 -c '
import yaml
with open("install-config.yaml", "rb") as yamlData:
    data = yaml.safe_load(yamlData)

data.update({"networking": {"networkType": "OVNKubernetes"}})
with open("install-config.yaml", "w") as yamlFile:
    yaml.dump(data, yamlFile, default_flow_style=False, allow_unicode=True)
'
}

function CreateManifests() {
    openshift-install create manifests --log-level=DEBUG

    # Create a new manifests that will allow for a hybrid network setup
    # this is required since there will be both windows and linux nodes
    pushd manifests
    # See the following the link for more information:
    # https://docs.openshift.com/container-platform/4.11/networking/ovn_kubernetes_network_provider/configuring-hybrid-networking.html#configuring-hybrid-ovnkubernetes
    # The CIDR and hybridOverlayVXLANPort can be altered for your installation
    if [ ! -f "cluster-network-03-config.yml" ]; then
	cat <<EOF > cluster-network-03-config.yml
apiVersion: operator.openshift.io/v1
kind: Network
metadata:
  name: cluster
spec:
  clusterNetwork:
  - cidr: 10.128.0.0/14
    hostPrefix: 23
  externalIP:
    policy: {}
  networkType: OVNKubernetes
  serviceNetwork:
  - 172.30.0.0/16
  defaultNetwork:
    type: OVNKubernetes
    ovnKubernetesConfig:
      hybridOverlayConfig:
        hybridClusterNetwork:
        - cidr: 10.132.0.0/14
          hostPrefix: 23
EOF
    fi
    popd
}

function CreateCluster() {
    # Finish the installation process
    openshift-install create cluster --log-level=DEBUG
}

function ConfigureWindows() {
    # set this so we can use `oc` with the cluster
    export KUBECONFIG=auth/kubeconfig

    # Create a namespace through a yaml file
    if [ ! -f "wmco-namespace.yaml" ]; then
	cat <<EOF > wmco-namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: openshift-windows-machine-config-operator
  labels:
    openshift.io/cluster-monitoring: "true"
EOF
    fi
    oc create -f wmco-namespace.yaml


    # Create a new operator group for Windows
    if [ ! -f "wmco-og.yaml" ]; then
	cat <<EOF > wmco-og.yaml
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: windows-machine-config-operator
  namespace: openshift-windows-machine-config-operator
spec:
  targetNamespaces:
  - openshift-windows-machine-config-operator
EOF
    fi
    oc create -f wmco-og.yaml

# Create a new subscription for Windows
    if [ ! -f "wmco-sub.yaml" ]; then
	cat <<EOF > wmco-sub.yaml
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: windows-machine-config-operator
  namespace: openshift-windows-machine-config-operator
spec:
  channel: "stable"
  installPlanApproval: "Automatic"
  name: "windows-machine-config-operator"
  source: "redhat-operators"
  sourceNamespace: "openshift-marketplace"
EOF
    fi
    oc create -f wmco-sub.yaml


    # Add the secret for windows operators.
    # https://github.com/openshift/windows-machine-config-operator#create-a-private-key-secret
    # As noted in the link above, it is strongly recommended to use a different key than
    # the key used for cluster provisioning.
    PRIVATE_KEY_WINDOWS=/home/${USER}/.ssh/wmco
    oc create secret generic cloud-private-key --from-file=private-key.pem=${PRIVATE_KEY_WINDOWS} -n openshift-windows-machine-config-operator

    # If this is already created then don't delete it later
    if [ ! -d "windows-machine-config-operator" ]; then
	git clone git@github.com:openshift/windows-machine-config-operator.git
    fi

    INSTALLED_PATH=`pwd`
    cd windows-machine-config-operator/hack

    # if this is already created, then don't delete it later
    if [ ! -d "auth" ]; then
	ln -s ${INSTALLED_PATH}/auth auth
    fi

    ./machineset.sh apply

    # Not using a stack here so no push/pop, change back to the original Dir
    cd ${INSTALLED_PATH}
}


case "${1:-}" in
    'config')
	InstallConfig;
	;;
    'manifests')
	CreateManifests;
	;;
    'cluster')
	CreateCluster;
	;;
    'windows')
	ConfigureWindows;
	;;
    'destroy')
	openshift-install destroy cluster;
	;;
    '')
	if [ ! -d "openshift" ] || [ ! -d "manifests" ]; then
	    if [ ! -f "install-config.yaml" ]; then
		InstallConfig;
	    fi
	    CreateManifests;
	elif [ ! -f "install-config.yaml" ]; then
	    InstallConfig;
	fi

	if [ ! -d "auth" ]; then
	    CreateCluster;
	fi

	export KUBECONFIG=auth/kubeconfig
	# Winwoker is a a named machineset from the machineset script above
	RESULTS=`oc get machinesets -A | grep winworker | wc -l`

	if [ "$RESULTS" -gt 0 ]; then
	    MACHINESET=`oc get machinesets -A | grep winworker | awk '{print $2}'`
	    echo "Machineset is already created: ${MACHINESET}"
	else
	    ConfigureWindows;
	fi
	;;
esac
