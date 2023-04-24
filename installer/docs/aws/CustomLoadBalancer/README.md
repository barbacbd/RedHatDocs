# Providing API and API-Int Addresses to Infrastructure - Proof of Concept

The original enhancement for this proposed work can be found [here](https://github.com/openshift/enhancements/pull/1276).

The Proof of Concept PR can be found in [PR 6914](https://github.com/openshift/installer/pull/6914).

## What is the PR doing ?

1. When the user has set `userConfiguredDNS` to enabled through the install config, the cluster-infrastructure manifest will be edited to include a blank [DNS Config](https://github.com/openshift/api/pull/1397).

**EDIT**: Passing a new terraform variable for `custom dns` so that the 
manifest does not need to be edited in any way prior to terraform `apply`. The manifest will be merged with new for the custom dns solution.

2. During the ignition config creation stage, the data from the cluster-infrastructure manifest is stripped out and replaced with a _plain text_ placeholder or template. The ignition file contains encoded data, so the search for plain text will be easy to find and replace. The stripped contents are provided as a terraform variable to the applied stages.
3. During the cluster stage in terraform, the dns information is found for the load balancers (not part of the PR).
4. During the bootstrap stage in terraform:
    * The manifest yaml data is converted to a map from a yaml string.
    * The load balancer DNS names are converted to a list of ip addresses for internal and external load balancers.
    * The yaml data is searched to determine if the [DNS Config](https://github.com/openshift/api/pull/1397) information was inserted. If it was, then the map has the API and API-Int load balancer data added. If not, the map is unedited.

      * **EDIT**: A new map is created with the load balancer data above if the custom dns solution variable was passed in. 

    * The maps are merged.
    * The resultant map is converted back into yaml.
    * The yaml data is encoded and placed into the ignition file where the placeholder was added in the second step above.
5. The edited manifest should appear on the bootstrap node.

## Custom Install Instructions

1. Create your install config. You **cannot** add `userConfiguredDNS` yet.
2. Manually generate the manifests with `openshift-install generate manifests`.
3. Change directories to the `manifest` directory.
4. Run the following to manually add the same placeholders that _would_ appear in code:

_I understand that this is just a PoC and this can never be relied upon as a solution._

```bash
#!/bin/python3

from yaml import safe_load, dump
from os import getcwd
from os.path import join, exists


manifest = "cluster-infrastructure-02-config.yml"

# Get the current working directory
cwd = getcwd()
print("Current working directory: {}".format(cwd))

manifest = join(cwd, manifest)
print("Searching for {}".format(manifest))

if not exists(manifest):
    print("Failed to find {}".format(manifest))
    exit(1)

with open(manifest, "r") as manifest_file:
    manifest_yaml = safe_load(manifest_file.read())

# add templated data to the yaml file
manifest_yaml["status"]["platformStatus"]["aws"]["awsClusterDNSConfig"] = "test"

with open(manifest, "w") as manifest_file:
    dump(manifest_yaml, manifest_file)
```

5. Change directories back to the original.
6. Continue the installation as normal.

_Running on the branch `barbacbd:aws-infrastructure-custom-dns` will allow the user to ssh into the bootstrap node to verify the contents of the manifest (the boostrap destroy functionality was commented out for the terraform stage)._ You may find the bootstrap node IP address through the AWS web console or via the terraform variables output. After you have connected to the bootstrap node, the manifest can be found in `/opt/openshift/manifests/`. 
<br><br>
The following was observed on the bootstrap node:

```
"apiVersion": "config.openshift.io/v1"
"kind": "Infrastructure"
"metadata":
  "creationTimestamp": null
  "name": "cluster"
"spec":
  "cloudConfig":
    "name": ""
  "platformSpec":
    "aws": {}
    "type": "AWS"
"status":
  "apiServerInternalURI": "https://api-int.bbarbach-tftest.devcluster.openshift.com:6443"
  "apiServerURL": "https://api.bbarbach-tftest.devcluster.openshift.com:6443"
  "controlPlaneTopology": "HighlyAvailable"
  "cpuPartitioning": "None"
  "etcdDiscoveryDomain": ""
  "infrastructureName": "bbarbach-tftest-9556w"
  "infrastructureTopology": "HighlyAvailable"
  "platform": "AWS"
  "platformStatus":
    "aws":
      "awsClusterDNSConfig":
        "apiServerDNSConfig":
        - "LBIPAddress": "18.233.114.133"
          "RecordType": "A"
        - "LBIPAddress": "44.209.41.251"
          "RecordType": "A"
        - "LBIPAddress": "52.0.9.205"
          "RecordType": "A"
        - "LBIPAddress": "52.86.205.2"
          "RecordType": "A"
        - "LBIPAddress": "54.144.26.174"
          "RecordType": "A"
        "internalAPIServerDNSConfig":
        - "LBIPAddress": "10.0.130.109"
          "RecordType": "A"
        - "LBIPAddress": "10.0.154.12"
          "RecordType": "A"
        - "LBIPAddress": "10.0.174.254"
          "RecordType": "A"
        - "LBIPAddress": "10.0.178.17"
          "RecordType": "A"
        - "LBIPAddress": "10.0.205.198"
          "RecordType": "A"
      "region": "us-east-1"
    "type": "AWS"
```

**EDIT**: This isn't needed now. In the source set the `customDNS` parameter in `cluster/tfvars.go` to `true`. Recompile and it will work for now. 

## Other Options

1. Jinja/YAML templates. This is much more difficult with lists.
2. Bring your own load balancer(s).
3. Create a config map and place inside of the ignition file.

## Notes

1. If/When we need to convert DNS names into IP Addresses there is a resource in terraform that can do this:

```
data "dns_a_record_set" "example" {
  host = DNS_Name
}
```

The snippet requires the `dns` provider that we **do not** currently have in our repo.

**EDIT**: The DNS provider was pulled in using the [example](https://github.com/openshift/installer/blob/master/docs/dev/terraform.md#adding-a-new-terraform-provider). The provider allowed for #2 below to be completed during a successful install.  

2. We are **not** currently using lists for the returned type when DNS names are provided in AWS. Type setting/casting from a single type to a list in terraform is not quite as straight forward as `tolist` suggests.

**EDIT**: The returned type from the load balancer dns names is now used to lookup the load balancer IP Addresses. This list is supplied to the manifest. See the example output above. 

3. Templating lists is very difficult. Originally, the PR contained templates for the API and API-Int load balancer Addresses. The point was raised that there can be multiple of each. The placeholders generated in go would not work as the exact number would not be known in time. This is where a combination of Jinja and YAML could be used. It is also possible to accomplish this with the same code used in this PR. The issue though is that the keys of the map including:
- status
- platformStatus
- clusterDNSConfig
- APIServerDNSConfig
- InternalAPIServerDNSConfig

all must be known ahead of time (and any change would be required here and the go code).

**EDIT**: There may be a working PoC now with lists of objects that can be used. Technically there is still a lot of data that must be known in both terraform and the go source (such as the infrastructure keys/layout). 

4. The config map seems to be the same result with extra steps. We would still have to edit the ignition file, then the config map must be passed to MCO from the bootstrap node. 

5. Looking into properly merging maps as nested maps and objects do not get merged correctly (data is overwritten). Currently investigating [`deepmerge`](https://github.com/cloudposse/terraform-yaml-config/tree/0.2.0/modules/deepmerge). Deep merge is a custom provider, and does not contain the configuration elements required to be used out of the box. _Notice the output above, the original status information is missing_. 

**EDIT**: Adding the deep merge module appears to correctly merge nested maps

```
module "deepmerge" {
  source = "github.com/Invicton-Labs/terraform-null-deepmerge"

  maps = [
    local.infrastructure_yaml,
    local.extra_infra_data
  ]
}
```
Prior to the inclusion of this module merging overwrote data in the original map. The infrastructure manifest did not contain all of its original data, thus errors could and would occur.