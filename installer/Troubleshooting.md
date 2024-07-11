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
