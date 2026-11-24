# Cluster API

Rancher 2.15 installs Turtles with core CAPI. With `capi_providers_enabled: true`, `deploy` adds
the `rancher-turtles-providers` release: CAPRKE2, CAPD (`capd_enabled`, which follows
`install_docker`) and, once `capa_aws_access_key_id` and `capa_aws_secret_access_key` are set in
`secrets.yml`, CAPA with its `capa-credentials` and `cluster-identity` Secrets. Provider versions
and settings come from [`fleet/platform/`](../fleet/platform/) in the checkout, so a tag deploys the
providers it was tested with; `capi_providers_values_url` fetches another values file instead.

[`fleet/`](../fleet/README.md) holds ClusterClasses, a shared AWS identity and three example
clusters as Fleet bundles: `docker-rke2-example` (Docker containers on the host, for development,
and the preferred way to run RKE2 on Docker),
`aws-rke2-example` (EC2 behind an internal NLB) and `aws-eks-example` (EKS with a managed node
group). Turtles imports each cluster into Rancher once it is ready. Register them by adding
`fleet_apps_capi_templates` to `fleet_apps`, with its `repo` pointed at your fork, or by applying
[`fleet/gitrepo.yaml`](../fleet/gitrepo.yaml); both create the GitRepo `capi-cluster-templates` in
`fleet-local` with `keepResources`. Every example is applied, and the AWS ones create billable
resources once their `REPLACE_WITH_*` values are filled in, so delete those you do not want from
your fork first. In `fleet/`, `scripts/validate-repo.py` checks the manifests,
`scripts/check-platform.py` checks the management cluster, and `scripts/sync-providers.py` aligns
the provider pins with the Turtles release that the pinned Rancher bundles.
[fleet/README.md](../fleet/README.md) covers AWS setup, class variables, versions and upgrades of
running installations.

Until 2026-11-19 the templates lived in the rancher-fleet-clusters repository, now archived.
Installations that used it repoint their GitRepo at this repository, with the paths
`fleet/clusterclasses`, `fleet/identities` and `fleet/clusters`. Each `fleet.yaml` pins its bundle
name and Helm release name to the ones Fleet generated at the old repository root, so Fleet keeps
the existing bundles, releases and clusters.

**Settings:** [Cluster API](configuration.md#cluster-api).
