# Pull Secrets

This document describes the creation of pull secrets for RedHat products/projects.

**NOTE**: The CI pull secrets will change every ~30 days.


# Grab the pull secrets

Visit this [site](https://console.redhat.com/openshift/install/aws/installer-provisioned) and select `Download Pull Secret`.

You **will** be required to enter your username and password.

Once the file is downloaded, extract the informtion, and get the pull-secret.txt file.

I renamed the file to `all-pull-secrets.txt`. This is not necessary, but I wanted `pull-secrets.txt` to be the final document.


# Grab the CI pull secrets

Visit this [site](https://oauth-openshift.apps.ci.l2s4.p1.openshiftapps.com/oauth/token/request) to obtain the CI pull secret.

Copy the `oc` command on the page to login. After completing the login process run `oc registry login --to {{ filename }}`. The
pull secret will be in the form: 

```json
{
  "auths": {
    "registry.ci.openshift.org": {
      "auth": "{{ CI_PULL_SECRET }}"
    }
  }
}
```


# Combine the secrets into a single file

The following script will allow you to combine the secrets into a single file:

```bash
#!/bin/bash                                                                     

oc registry login --to ci-pull-secret.json

jq -c -s '.[0] * .[1]' ci-pull-secret.json all-pull-secrets.txt > pull-secrets.txt

# Creating copies rather than sim-links in the event that we accidentally
# change one and it links to all (or deletions).

# Copied for your convenience 
cp pull-secrets.txt ~/.docker/config.json

# copied for your convenience
cp pull-secrets.txt ~/

# copied for OI dev scripts
cp pull-secrets.txt ~/oi/pull-secret.json
```

Run this script everytime that the ci-pull-secret changes.

