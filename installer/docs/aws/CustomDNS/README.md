# AWS Custom Security Groups

The document is created to track the Proof of Concept work for the epic.

# Prospective Cards

1. Add Control Plane install config option (2/3 -> 3 with tests)

The control plane option should be added similar to the following:

```
additionalSecurityGroupIDs:
  description: AdditionalSecurityGroupIDs contains IDs of
    additional security groups for machines, where each ID
    is presented in UUID v4 format.
  items:
    type: string
  type: array
```

This should be added under the `AWS` platform.

Tests for the install configuration should be added.

2. Add Compute install config option (2/3 -> 3 with tests)

The compute option should be added similar to the following:

```
additionalSecurityGroupIDs:
  description: AdditionalSecurityGroupIDs contains IDs of
    additional security groups for machines, where each ID
    is presented in UUID v4 format.
  items:
    type: string
  type: array
```

This should be added under the `AWS` platform.

Tests for the install configuration should be added.


3. Add the ability to validate security groups (3/5)

**A VPC is required to create a security group. Do we also need to use this VPC during installation?**

4. Attach the security group to the nodes (5)

The work will need to be completed in `pkg/asset/machines`.

We _should_ change the aws::Machinesets function to accept an install config. Both the machines::workers and machines::masters call the aws::Machinesets function. The aws::Machinesets function calls the aws::provider function. Here the security group(s) can be attached during the configuration. 


# Add the ability to bring in a VPC or set of VPCs

**If the control plane and compute nodes use security groups from different VPC's then all of the VPC's need to be accessible**

**How do we choose what VPC to use?**

**Can we use multiple VPC's?**

**Fail if multiple VPCs are used**