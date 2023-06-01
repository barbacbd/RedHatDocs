#!/bin/bash

set -o nounset
set -o errexit
set -o pipefail

trap 'CHILDREN=$(jobs -p); if test -n "${CHILDREN}"; then kill ${CHILDREN} && wait; fi' TERM

export AWS_SHARED_CREDENTIALS_FILE="/home/${USER}/.aws/credentials"
REGION="us-east-1"
SHARED_DIR=/tmp

aws ec2 delete-security-group --region ${REGION} --group-id $(cat ${SHARED_DIR}/security_group)

echo "Deleting AWS CloudFormation stacks"
stack_list="${SHARED_DIR}/vpc_stack_name"
if [ -e "${stack_list}" ]; then
    for stack_name in `tac ${stack_list}`; do 
        echo "Deleting stack ${stack_name} ..."
        aws --region $REGION cloudformation delete-stack --stack-name "${stack_name}" &
        wait "$!"
        echo "Deleted stack ${stack_name}"

        aws --region $REGION cloudformation wait stack-delete-complete --stack-name "${stack_name}" &
        wait "$!"
        echo "Waited for stack ${stack_name}"
    done
fi


# remove files created during resource creation
if [ -f "01_vpc.yaml" ]; then
    rm 01_vpc.yaml
fi

rm -rf "${SHARED_DIR}/availability_zones"
rm -rf "${SHARED_DIR}/private_subnet_ids"
rm -rf "${SHARED_DIR}/public_subnet_ids"
rm -rf "${SHARED_DIR}/subnet_ids"
rm -rf "${SHARED_DIR}/vpc_id"
rm -rf "${SHARED_DIR}/vpc_stack_name"
rm -rf "${SHARED_DIR}/vpc_stack_output"
rm -rf "${SHARED_DIR}/security_group"

exit 0
