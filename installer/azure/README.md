# Azure Setup

## Installing Azure CLI

1. Import the microsoft repo key:
  `sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc`

2. Download the repo:
  `sudo dnf install -y https://packages.microsoft.com/config/rhel/8/packages-microsoft-prod.rpm`

3. Install the CLI (you can also install specific versions):
  `sudo dnf install azure-cli`

**Note**: _Installation assume RHEL/Fedora Distribution_.


## Start using the CLI

`az login`

**Note**: _This will bring up the azure site and ask for your login_.
**Note**: _You should see the output on the screen. The same information can be found int `~/.azure`_. 


## Create the credentials

The following information can be found in these [azure pages](https://docs.google.com/document/d/1Kzy4N8LQGozRmgmEaz_54CkzkjAbevMfnXfv7uvHkvk/edit). Note
that the data in [azure openshift docs](https://github.com/openshift/installer/tree/master/docs/user/azure) may be considered outdated. 

### Find your subscription ID

Find your subscription ID in `~/.azure` or use the azure cli.

```bash
cd ~/.azure;
grep -r subscription *
```
You should see a uuid formatted string. Find this string and use it in the next step.
The following will provide the information through the cli: `az account list`

This will provide the all of the accounts linked to your user. In this case we want to find the service principal linked
to the project for the installer.

#### Adjust current project

Find the current project with the following command: `az account show`.
If the project ID does not match the one that is desired (found above), set the project id to the one that
is desired by entering: `az account set --name <project_id>`


## Add Permissions to the account

The following command will add permissions to the new user:
`az ad sp create-for-rbac --role Owner --scopes /subscription/{SUBSCRIPTION_ID} --name {USERNAME}-{PURPOSE}`

In the snippet above:
- SUBSCRIPTION_ID - Id of the project found above (id in `az account show`)
- USERNAME - Main name of the service principal (I used `bbarbach-installer`)
- PURPOSE - What project you want this attached to 

**Note**: _In old versions the `--scopes` was not required, now it is_.

The output should be something similar to:

```json
{
  "appId": {uuid},
  "displayName": "bbarbach-installer",
  "password": {password},
  "tenant": {uuid}
}
```

I saved the file to `localAzureCreds.json`. This way we can look up the information required for
future installs. This is required when a new account is setup, or when the osServicePrincipal.json file
is not present in `~/.azure`.

## Installing cluster

Follow the snippet below inputting data from above examples

```bash
$ openshift-install create cluster
? SSH Public Key /home/{USER}/.ssh/{ssh-key}.pub
? Platform azure
? azure subscription id {SUBSCRIPTION_ID}
? azure tenant id {tenant}
? azure service principal client id {appId}
? azure service principal client secret [? for help] {password}
INFO Saving user credentials to "/home/{USER}/.azure/osServicePrincipal.json" 
INFO Credentials loaded from file "/home/{USER}/.azure/osServicePrincipal.json"
```

**Note**: _Assumes that `openshift-installer` is in path_.

