# Cluster API GCP Provider

The project can be found at [cluster-api-provider-gcp](https://github.com/kubernetes-sigs/cluster-api-provider-gcp/tree/main). The main documentation for the project is found [here](https://github.com/kubernetes-sigs/cluster-api-provider-gcp/tree/main/docs).

The [development guide](https://github.com/kubernetes-sigs/cluster-api-provider-gcp/tree/main/docs) and [releasing guidelines](https://github.com/kubernetes-sigs/cluster-api-provider-gcp/blob/main/docs/book/src/developers/releasing.md) may be useful for future work.

# Submitting PRs

The following should be executed before submitting any PR:

- `make generate` (for api updates)
- `make lint`
- `make test`

# Additions to API

If you experience issues with unknown components or components always resulting in `nil` values in CAPG, update the infrastructure components file.

- `make release-manifests`

# New additions

The project is new, and there may be breaking changes. Reach out to the team about possible breaking changes. Also note that in the event that a change could be breaking or experimental you can add experimental api updates to the `exp` directory in the project root.