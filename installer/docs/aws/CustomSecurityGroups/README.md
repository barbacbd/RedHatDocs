# AWS Custom Security Groups

The document is created to track the Proof of Concept work for the epic.

## Prospective Cards

The following sections detail the cards and/or potential work to achieve this enhancement.

  * [Control Plane Changes to Install Config (2/3 points)](#add-control-plane-install-config-option)
  * [Compute Changes to Install Config (2/3 points)](#add-compute-install-config-option)
  * [Alter the install config validation (5 points)](#alter-the-install-config-validation)
  * [Add VPC ID to the install config - Optional (2/3 points)](#add-vpc-id-to-the-install-config)
  * [Alter the way that the VPC is discovered (3/5 points)](#alter-the-way-that-the-vpc-is-discovered)
  * [Provide information to terraform indicating pre existing security group(s) (2/3 points)](#provide-information-to-terraform-indicating-pre-existing-security-groups)
  * [Remove the creation of security group rule (2 points)](#remove-the-creation-of-security-group-rule)
  * [Remove the creation of the security group (2 points)](#remove-the-creation-of-the-security-group)
  * [Attach the security group to the nodes (3/5 points)](#attach-the-security-group-to-the-nodes)
  * [Alterations to destroy process (3 points)](#alterations-to-destroy-process)

### Add Control Plane install config option

The control plane option should be added similar to the following:

```
additionalSecurityGroupIDs:
  description: AdditionalSecurityGroupIDs contains IDs of
    additional security groups for machines, where each ID
    is presented in the format sg-xxxx.
  items:
    type: string
  type: array
```

This should be added under the `AWS` platform.

Tests for the install configuration should be added. This includes static tests in `types/{platform}/validate` to ensure that the format for the security group abides by the `sg-XXXX` where the prefix must be `sg-`. The maximum length is 2000 character according to AWS docs online. AWS does **not** allow users to alter the ID of Security Groups, so the format _should_ remain. **This may be optional since we can perform a lookup detailed below**. 

### Add Compute install config option

The compute option should be added similar to the following:

```
additionalSecurityGroupIDs:
  description: AdditionalSecurityGroupIDs contains IDs of
    additional security groups for machines, where each ID
    is presented in the format sg-xxxx.
  items:
    type: string
  type: array
```

This should be added under the `AWS` platform.

Tests for the install configuration should be added. This includes static tests in `types/{platform}/validate` to ensure that the format for the security group abides by the `sg-XXXX` where the prefix must be `sg-`. The maximum length is 2000 character according to AWS docs online. AWS does **not** allow users to alter the ID of Security Groups, so the format _should_ remain. **This may be optional since we can perform a lookup detailed below**. 

<br>

### Alter the install config validation

The machine pool(s) for AWS must be verified in install config code. To do this, the EC2 client can be queried to grab [Security Group information](https://pkg.go.dev/github.com/aws/aws-sdk-go-v2/service/ec2#Client.DescribeSecurityGroups). The data that is received from the query can be found [here](https://pkg.go.dev/github.com/aws/aws-sdk-go-v2/service/ec2#DescribeSecurityGroupsOutput). Verify that the VPCs are all the same, and if they are not, then an error must be raised. 

<br>

The EC2 client is already used in the `installconfig/aws` directory. While we are here, consider breaking some of these uses out. Create an interface for EC2 here similar to the Route53 interface. 

<br>

### Add VPC ID to the install config

When the user adds `additionalSecurityGroupIDs` in the compute and/or control plane nodes, then **all** security groups must be linked to the same VPC. The expected VPC can be added to the `aws` platform in the install-config by adding the following snippet to the yaml file under the appropriate section.

```
vpcID:
  description: VpcID is the ID of an already existing VPC where
    the cluster should be installed. If empty, the installer will
    create a new VPC for the cluster.
  type: string
```

<br>
_Instead of leaving the burden on the user, the installer can check if multiple VPC's are required based on the supplied security group ID's._

<br>
No Matter which of the options in this section are used, the VPC will be required for further use. The VPC ID must be saved and passed to terraform. When the VPC ID is passed to terraform, a new VPC must **not** be created (instead the existing VPC is used).

The option already exists to use an existing VPC in the aws terraform code.

```
variable "aws_vpc" {
  type        = string
  default     = null
  description = "(optional) An existing network (VPC ID) into which the cluster should be installed."
}
```

### Alter the way that the VPC is discovered

[TODO]: Investigate what the VPC() function is doing when discovering and uncovering the subnets. Do we still need this process?

1. Find the VPC that should be used based on the security groups
2. Find all of the subnets based on the VPC
3. Change the VPC and populateSubnets function to allow selecting data using this method.

https://docs.aws.amazon.com/sdk-for-go/api/service/ec2/#DescribeSubnetsInput

<br>

### Provide information to terraform indicating pre existing security group(s)

Provide a value `ExistingSecurityGroup` (or something similar) when the security group exists before the installer is asked to create the data. 

<br>

### Remove the creation of security group rule

When security groups are provided (both master and worker), there is no need to create the security group rules. Set the count to `0` when this is the case. This can be found in:
- `data/data/aws/cluster/vpc/sg-master.tf`
- `data/data/aws/cluster/vpc/sg-worker.tf`

<br>

### Remove the creation of the security group

When security groups are provided (both master and worker), there is no need to create the security group again. Set the count to `0` when this is the case. This can be found in:
- `data/data/aws/cluster/vpc/sg-master.tf`
- `data/data/aws/cluster/vpc/sg-worker.tf`

<br>

### Attach the security group to the nodes

The work will need to be completed in `pkg/asset/machines`.

Alter aws::Machinesets() to accept an install config. Both the machines::workers and machines::masters call the aws::Machinesets function. aws::Machinesets() calls the aws::provider(). Here the security group(s) can be attached during the configuration. 

**Note**: _According to the data in the original spike, it is stated that the user provided security groups are in addition to the ones that are created. This must still be investigated._

<br>

### Alterations to destroy process

Verify that the destroy code will or will not have to be altered. Currently it appears that it does not require alterations. The resource is searched via the ARN. The `id` that is used to find the security group(s) should not be associated with the ARN.

The deletion of the VPC may need to be altered as it _may_ fail when the vpc cannot be found. 