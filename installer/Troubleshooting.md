# Troubleshooting the cluster

There are many ways to debug the cluster. This doc will be a running list of methods that we can use to debug the cluster.

## Webconsole - 

1. Look at the CI to determine what server the job is executing on.

This means that you should see something similar to `Using namespace XXXXXXXXXXXXXXXXXXXXXXX/k8s/cluster/projects/ci-op-xxxxxx `. This will tell us the build server where the data exists. For security purposes the build servers cannot and will not be posted here.

2. Open the web console for the server that your cluster is running on.

3. Selection "Administrator" (not "Developer") in the top left.

4. Select the project indicated in the CI job in the "Project" drop down in the top left.

5. On the left hand side, open the "Workloads" and select "PODS".

6. Find the POD that correlates to the Cluster installation becoming available.

7. In the bar at the top (under the pod name), select terminal.

8. Navigate to `/tmp/installer`

9. `cat kubeconfig` and copy the contents to your host machine.

10. Use the kubeconfig to run `oc` machines.

** Note: You may need to add a "Sleep" to a CI job step to ensure that the pod is available long enough to allow you to execute the steps above.**


## CCO permissions

First check to see if any of the pods or nodes are failing:

```
oc get co
```

```
oc get pods -A
```

In this case, the `oc get co` command may show something like

```
cloud-credential                           4.18.0-0.nightly-2024-10-23-055519   True        True          True       74m     1 of 7 credentials requests are failing to sync.
```

From here we could see what is failing with something like:

```
oc get credentialsrequests -n openshift-cloud-credential-operator -o yaml
```

We should now have the instance that is failing. From here we can get the yaml file that describes the issue. In this example the issue is `openshift-gcp-pd-csi-driver-operator`.

```
oc get credentialsrequests openshift-gcp-pd-csi-driver-operator -n openshift-cloud-credential-operator -o yaml
```

And the output might show something like:

```
apiVersion: cloudcredential.openshift.io/v1
kind: CredentialsRequest
metadata:
... data ...
spec:
  providerSpec:
    apiVersion: cloudcredential.openshift.io/v1
    kind: GCPProviderSpec
    permissions:
    - compute.instances.get
    - compute.instances.attachDisk
    - compute.instances.detachDisk
    predefinedRoles:
    - roles/compute.storageAdmin
    - roles/iam.serviceAccountUser
    - roles/resourcemanager.tagUser             <<<<< Missing Permission in this case
    skipServiceCheck: true
  secretRef:
    name: redacted
    namespace: openshift-cluster-csi-drivers
  serviceAccountNames:
  - redacted
status:
... more data ...
```