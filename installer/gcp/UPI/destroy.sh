#!/bin/bash
set -x
export TARGETDIR="${1:-assets}"

#rm ${TARGETDIR}/*.py
rm ${TARGETDIR}/*.yaml
rm ${TARGETDIR}/service-account-key.json

if [ -f ${TARGETDIR}/metadata.json ]; then
    export INFRA_ID=$(jq -r .infraID ${TARGETDIR}/metadata.json)
fi

# Use openshift-install to delete the cluster.
openshift-install --log-level=debug --dir=${TARGETDIR} destroy cluster

if [ ! -z $INFRA_ID ]; then
  # Delete the deployments
  gcloud -q deployment-manager deployments delete \
    ${INFRA_ID}-worker \
    ${INFRA_ID}-control-plane \
    ${INFRA_ID}-bootstrap \
    ${INFRA_ID}-security \
    ${INFRA_ID}-dns \
    ${INFRA_ID}-firewall \
    ${INFRA_ID}-iam \
    ${INFRA_ID}-infra \
    ${INFRA_ID}-cluster \
    ${INFRA_ID}-vpc
fi

rm -rf ${TARGETDIR}/manifests
rm -rf ${TARGETDIR}/openshift
rm -rf ${TARGETDIR}/*.ign
rm -rf ${TARGETDIR}/.openshift_install.log
rm -rf ${TARGETDIR}/.openshift_install_state.json
