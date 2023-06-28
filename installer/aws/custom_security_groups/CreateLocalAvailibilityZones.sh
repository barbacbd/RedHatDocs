#!/bin/sh

set -o nounset
set -o errexit
set -o pipefail

export AWS_SHARED_CREDENTIALS_FILE="/home/${USER}/.aws/credentials"
EXPIRATION_DATE=$(date -d '4 hours' --iso=minutes --utc)
CLUSTER_REGION="us-east-1"
CLUSTER_NAME="example-cluster-name"
STACK_VPC="" # cloud formation vpc name

# Choosing randomly the AZ withing the Region (best choice to test any AZ - and detect possible errors)
AZ_NAME=$(aws --region $CLUSTER_REGION \
  ec2 describe-availability-zones \
  --filters Name=opt-in-status,Values=opted-in Name=zone-type,Values=local-zone \
  | jq -r .AvailabilityZones[].ZoneName | shuf | head -n1)

# Force the name
AZ_SUFFIX=$(echo ${AZ_NAME/${CLUSTER_REGION}-/})

AZ_GROUP=$(aws --region $CLUSTER_REGION \
  ec2 describe-availability-zones \
  --filters Name=zone-name,Values=$AZ_NAME \
  | jq -r .AvailabilityZones[].GroupName)

export STACK_LZ=${CLUSTER_NAME}-lz-${AZ_SUFFIX}
export ZONE_GROUP_NAME=${AZ_GROUP}
export VPC_ID=$(aws --region $CLUSTER_REGION \
  cloudformation describe-stacks --stack-name ${STACK_VPC} \
  | jq -r '.Stacks[0].Outputs[] | select(.OutputKey=="VpcId").OutputValue' )

export VPC_RTB_PUB=$(aws --region $CLUSTER_REGION \
  cloudformation describe-stacks --stack-name ${STACK_VPC} \
    | jq -r '.Stacks[0].Outputs[] | select(.OutputKey=="PublicRouteTableId").OutputValue' )

aws --region $CLUSTER_REGION ec2 modify-availability-zone-group \
    --group-name "${ZONE_GROUP_NAME}" \
    --opt-in-status opted-in

aws cloudformation create-stack \
  --region ${CLUSTER_REGION} \
  --stack-name ${STACK_LZ} \
  --template-body file://template-lz.yaml \
  --parameters \
    ParameterKey=ClusterName,ParameterValue="${CLUSTER_NAME}" \
    ParameterKey=VpcId,ParameterValue="${VPC_ID}" \
    ParameterKey=PublicRouteTableId,ParameterValue="${VPC_RTB_PUB}" \
    ParameterKey=LocalZoneName,ParameterValue="${ZONE_GROUP_NAME}a" \
    ParameterKey=LocalZoneNameShort,ParameterValue="${AZ_SUFFIX}" \
    ParameterKey=PublicSubnetCidr,ParameterValue="10.0.128.0/20"

aws --region ${CLUSTER_REGION} cloudformation wait stack-create-complete --stack-name ${STACK_LZ}
aws --region ${CLUSTER_REGION} cloudformation describe-stacks --stack-name ${STACK_LZ}
