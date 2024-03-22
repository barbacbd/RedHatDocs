# Release

Release is the CI repository for the main testing that Red Hat executes for openshift projects.

## Presubmit Execution

```
make update
```

If you do not not have docker (podman instead), attempt to execute with the following:

```
CONTAINER_ENGINE=podman make update
```

If these tests do not work, ensure that your credentials are correctly setup (see [secrets](../installer/secrets/README.md)). The credentials **must** be updated in `/home/{USER}/.docker/config.json`.