# VSPHERE

## Establish Credentials

You should receive your credentials as a GPG file such as `<user>@redhat.com.credentials.txt.gpg`. Before proceeding, it is recommended that you create a temporary directory called `~/vsphere_creds/`. Move the GPG file to the directory you just created. The GPG file should be decrypted to a text file with a command similar to the following:

```bash
gpg --decrypt --output <user>_vsphere_creds.txt <user>@redhat.com.credentials.txt.gpg
```

Your credentials should be stored in the txt file `<user>_vsphere_creds.txt`. `cat` the file to take a look:

```bash
AWS account: openshift-vmware-cloud-ci 
URL: https://openshift-vmware-cloud-ci.signin.aws.amazon.com/console

Username: {user}
Initial password: {password}

Run the following command to update your AWS credentials files:

$ aws configure --profile=openshift-vmware-cloud-ci
AWS Access Key ID [None]: {id}
AWS Secret Access Key [None]: {secret}
Default region name [None]: us-east-1   (or whichever region you chose)
Default output format [None]: text
```

## Configure Profile

AWS Credentials live in `~/.aws/credentials`, and configuration information is stored in `~/.aws/config`. The information above needs to be added to both files. Use the following as an example:

### Credentials

```bash
[openshift-dev]
aws_access_key_id = {dev-id}
aws_secret_access_key = {dev-secret}

[openshift-vmware-cloud-ci]
aws_access_key_id = {vsphere-id}
aws_secret_access_key = {vsphere-creds}

[default]
aws_access_key_id = {dev-id}
aws_secret_access_key = {dev-secret}
```

The default is set to the same data as the profile that you wish to be the default.

### Configuration

```bash
[profile openshift-dev]
region = us-east-2
output = text

[profile openshift-vmware-cloud-ci]
region = us-east-1
output = text
```

## Notes

If you have account information already added, you will need to override the environment variable `AWS_PROFILE`.

_This variable should be set each time an installation is executing using the openshift installer_.

```bash
export AWS_PROFILE="openshift-vmware-cloud-ci"
```
