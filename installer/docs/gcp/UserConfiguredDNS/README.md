# User Configured DNS

The following are approaches will be explored:

1. Edit the bootstrap ignition to include a config map so that it lands on the bootstrap node during ignition.
2. Have the installer itself update the config map in cluster, once the api becomes available on the bootstrap node (the approach requires that the installer can communicate to the api without an external DNS record).
3. Executing an operator on the bootstrap node to update the config map. 

This document will follow the requirements for number 1 and 2 above. 

# Applying config map to bootstrap node

## What is the problem

The installer needs to add a config map to the bootstrap node. The config map should contain the ip addresses and/or the dns names of the public and private load balancers. To accomplish this, the bootstrap ignition process will get the data onto the bootstrap node. The problem is that the bootstrap ignition is generated before the terraform variables are generated and sent to terraform. The installer is able to get the load balancer ip addresses/dns names during terraform. There is no way to exit and reenter terraform, but we can add stages that run between terraform modules are applied. 

## Approaches

The following are approaches that were explored:

1. Add a template to the bootstrap ignition file. When the user has selected a user configured DNS solution, the template is edited inside of terraform. 
2. Run updates to the bootstrap ignition generation, so that it is regenerated and reused during terraform.
3. Update the json data that contains the terraform variable for bootstrap ignition. Append the new load balancer config map. 

### Templates

The template method was already explored for AWS in the [doc](https://github.com/barbacbd/RedHatDocs/tree/main/installer/docs/aws/CustomLoadBalancer/README.md). 

### Regenerating Assets

The bootstrap ignition is an Asset in the installer. Assets can be regenerated from the installer asset graph. The installer could purge any saved state of the bootstrap ignition, regenerate the data, and then replace the data in the terraform variables file. 

```go
assetStore, err := assetstore.NewStore(directory)
if err != nil {
    return errors.Wrap(err, "failed to create asset store")
}

// destroy the asset so that it can be regenerated.
bs := &bootstrap.Bootstrap{}
err = assetStore.Destroy(bs)
if err != nil {
    err = errors.Wrapf(err, "failed to destroy %s", bs.Name())
}


// Regenerate now that the bootstrap node has been purged.
err := assetStore.Fetch(bs)
if err != nil {
    err = errors.Wrapf(err, "failed to fetch %s", bs.Name())
}
```

This method requires that the installer add changes to Bootstrap ignition asset. If the config map exists, then it is to be added to the ignition file. 

### Update terraform variables directly 

This method is very similar to that of the asset regeneration. The setup is the exact same, but the installer will edit the data stored in the terraform variables file and save the data to be reused. 

```go
// Load the ignition data to a common ignition structure
ignData := igntypes.Config{}
err = json.Unmarshal([]byte(ignitionBootstrap.(string)), &ignData)
if err != nil {
    return "", err
}

// Append the contents of the load balancer config map to the ignition config. 
ignData.Storage.Files = append(ignData.Storage.Files, ignition.FileFromString(path, "root", 0644, lbConfigContents))

ignitionOutput, err := json.Marshal(ignData)
if err != nil {
    return "", err
}
// Update the ignition bootstrap variable to include the lbconfig.
tfvarData["ignition_bootstrap"] = string(ignitionOutput)

// Convert the bootstrap data and write the data back to a file. This will overwrite the original tfvars file.
jsonBootstrap, err := json.Marshal(tfvarData)
if err != nil {
    return "", fmt.Errorf("failed to convert bootstrap ignition to bytes: %w", err)
}
tfvarsFile.Data = jsonBootstrap
```

### Common Ground

The methods above will require a post terraform module stage to be executed (this is new to the installer). 

```go
_, extErr := stage.ExtractLBConfig(dir, terraformDirPath, outputs, vars[0])
if extErr != nil {
    return fileList, fmt.Errorf("failed to extract load balancer information: %w", extErr)
}
```

The snippet above will run the load balancer extraction if it exists. 

To be able to run this code the Stage interface must be edited to include the new function:

```go
// ExtractLBConfig extracts the LB DNS Names of the internal and external API LBs.
ExtractLBConfig(directory string, terraformDir string, file *asset.File, tfvarsFile *asset.File) (ignition string, err error)
```

