# Cluster API GCP Provider

The project can be found at [cluster-api-provider-gcp](https://github.com/kubernetes-sigs/cluster-api-provider-gcp/tree/main). The main documentation for the project is found [here](https://github.com/kubernetes-sigs/cluster-api-provider-gcp/tree/main/docs).

The [development guide](https://github.com/kubernetes-sigs/cluster-api-provider-gcp/tree/main/docs) and [releasing guidelines](https://github.com/kubernetes-sigs/cluster-api-provider-gcp/blob/main/docs/book/src/developers/releasing.md) may be useful for future work.

# Submitting PRs

The following should be executed before submitting any PR:

- `make generate` (for api updates)
- `make lint`
- `make test`
