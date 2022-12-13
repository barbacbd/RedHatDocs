# Troubleshooting

## Failure During Kube API

The following error (or similar) may be seen
```
DEBUG Still waiting for the Kubernetes API: Get "https://api.bbarbach-xpn.installer.gcpxpn.devcluster.openshift.com:6443/version": dial tcp 35.227.103.128:6443: i/o timeout
```

This is an indicator that the ignition is not able to be fetched. Confirm this checking the log bundle in the directory `serial`. Search for the text `fetch` in the bootstrap node log file. This will confirm that the ignition was unable to be fetched if there are errors surrounding this text.

Check the `boostrap/journals/bootkube.log` file.
<br><br>
If you see the error `Error: unknown flag: --feature-set`, this means that the Release image may be out of date. Check the environment variable `OPENSHIFT_INSTALL_RELEASE_IMAGE_OVERRIDE`, and it may reveal an out of date release.

**Note**: _It is possible that the release version needs to be bumped forcefully. For example the release may be 4.12, but the current version is 4.13 (auto bump it)._


