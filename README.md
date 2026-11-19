# rancher-platform

[![E2E](https://github.com/mbologna/rancher-platform/actions/workflows/e2e.yml/badge.svg)](https://github.com/mbologna/rancher-platform/actions/workflows/e2e.yml)
[![Lint](https://github.com/mbologna/rancher-platform/actions/workflows/lint.yml/badge.svg)](https://github.com/mbologna/rancher-platform/actions/workflows/lint.yml)
[![Version](https://img.shields.io/github/v/tag/mbologna/rancher-platform?label=version)](https://github.com/mbologna/rancher-platform/tags)

rancher-platform deploys a [Rancher](https://www.rancher.com/) management cluster on one Linux
host in about seven minutes. Ansible installs RKE2, cert-manager and Rancher on a host you have,
on an EC2 instance that OpenTofu creates, or on a Lima VM on a Mac. Rancher can then manage kind
clusters on the same host, deploy apps from Git to every cluster with Fleet, and provision
Cluster API (CAPI) clusters through [Rancher Turtles](https://turtles.docs.rancher.com/)
from the templates in [`fleet/`](fleet/README.md): RKE2 on Docker, RKE2 on AWS and Amazon EKS.

## What you get

- RKE2 (Kubernetes v1.36), cert-manager and Rancher 2.15, at `rancher.<ip>.sslip.io` or a name
  you choose, with a self-signed or Let's Encrypt certificate.
- [Liz, the Rancher AI Assistant](https://documentation.suse.com/cloudnative/rancher-ai/1.1.0/en/quick-start.html):
  agent, MCP server and UI extension; you configure the LLM in the Rancher UI.
- Optional downstream clusters on the same host: kind clusters imported into Rancher, or RKE2
  clusters that Rancher provisions on Docker containers.
- Fleet apps from Git repositories on every cluster, four samples, and Ingresses at
  `http://<app>.<ip>.sslip.io`.
- CAPI providers for Turtles (RKE2, Docker and, with AWS keys, AWS), with ClusterClasses and three
  example clusters in `fleet/`.
- Helm chart presets for Rancher Monitoring, Rancher Backups, Kubewarden, Longhorn and Harbor.
- etcd snapshots every 12 hours with snapshot and restore commands, optional S3 upload, and an
  optional pull-through image cache.
- One kubeconfig with a context per cluster, all reached through Rancher on port 443.

Versions are pinned in [`config.yml`](ansible/group_vars/all/config.yml) and
[`fleet/platform/`](fleet/platform/), and Renovate updates them.

## Quick start

Run the commands from the repository root unless noted. All of them are safe to re-run.

1. Get a Linux host you can SSH into as root or with passwordless sudo: openSUSE Leap 16.0,
   SLES 15 SP7, or Ubuntu 22.04 or 24.04, with 4 vCPUs, 16 GB RAM, 100 GB disk and ports 80
   and 443 reachable from your browser. Use one of three options, described in
   [docs/hosts.md](docs/hosts.md):

   ```bash
   # A host you have: set ansible_host
   cp ansible/inventory/hosts.yml.example ansible/inventory/hosts.yml
   # A new EC2 instance (OpenTofu or Terraform 1.6+): set region, SSH key, source CIDRs
   cp terraform/terraform.tfvars.example terraform/terraform.tfvars
   tofu -chdir=terraform init && tofu -chdir=terraform apply
   # A Lima VM on a Mac: add -i inventory/lima.yml to the manage.sh commands below
   ./local/lima.sh up
   ```

2. Install Rancher. You need ansible-core 2.18 or later (the playbook checks). Set `rancher_bootstrap_password`
   (12 or more characters) in `secrets.yml`, then deploy from `ansible/`, where every
   `./manage.sh` command runs:

   ```bash
   cd ansible
   cp group_vars/all/secrets.yml.example group_vars/all/secrets.yml
   ./manage.sh install   # pinned Ansible collections
   ./manage.sh deploy
   ```

   Open `https://<rancher_hostname>` and log in as `admin`.

3. Optionally, add clusters and apps. Each name in `downstream_clusters` becomes a kind cluster
   `rp-<name>` imported into Rancher; [docs/clusters-and-apps.md](docs/clusters-and-apps.md)
   covers RKE2 clusters provisioned by Rancher, Fleet apps and Helm charts, and
   [Cluster API](#cluster-api) covers CAPI. Set the lists in `config.yml` to keep them.

   ```bash
   ./manage.sh deploy -e '{"downstream_clusters": ["dev", "staging"]}'
   ```

4. Use the clusters. `deploy` writes a kubeconfig with an `admin` token valid for 30 days;
   `./manage.sh kubeconfig` replaces it.

   ```bash
   export KUBECONFIG=~/.kube/rancher-platform.yaml
   kubectl config get-contexts   # <host>, <host>-dev, <host>-staging
   ```

5. Tear it down with `tofu -chdir=terraform destroy` (AWS) or `./local/lima.sh down` (Lima).
   On your own host, follow [docs/operations.md](docs/operations.md#tear-it-down).

[docs/operations.md](docs/operations.md) lists every `./manage.sh` command and covers upgrades,
snapshots, development builds, the image cache and troubleshooting.

## Cluster API

Rancher 2.15 installs Turtles with core CAPI. With `capi_providers_enabled: true`, `deploy` adds
the `rancher-turtles-providers` release: CAPRKE2, CAPD (`capd_enabled`, which follows
`install_docker`) and, once `capa_aws_access_key_id` and `capa_aws_secret_access_key` are set in
`secrets.yml`, CAPA with its `capa-credentials` and `cluster-identity` Secrets. Provider versions
and settings come from [`fleet/platform/`](fleet/platform/) in the checkout, so a tag deploys the
providers it was tested with; `capi_providers_values_url` fetches another values file instead.

[`fleet/`](fleet/README.md) holds ClusterClasses, a shared AWS identity and three example
clusters as Fleet bundles: `docker-rke2-example` (Docker containers on the host, for development),
`aws-rke2-example` (EC2 behind an internal NLB) and `aws-eks-example` (EKS with a managed node
group). Turtles imports each cluster into Rancher once it is ready. Register them by adding
`fleet_apps_capi_templates` to `fleet_apps`, with its `repo` pointed at your fork, or by applying
[`fleet/gitrepo.yaml`](fleet/gitrepo.yaml); both create the GitRepo `capi-cluster-templates` in
`fleet-local` with `keepResources`. Every example is applied, and the AWS ones create billable
resources once their `REPLACE_WITH_*` values are filled in, so delete those you do not want from
your fork first. In `fleet/`, `scripts/validate-repo.py` checks the manifests,
`scripts/check-platform.py` checks the management cluster, and `scripts/sync-providers.py` aligns
the provider pins with the Turtles release that the pinned Rancher bundles.
[fleet/README.md](fleet/README.md) covers AWS setup, class variables, versions and upgrades of
running installations.

Until 2026-11-19 the templates lived in the rancher-fleet-clusters repository, now archived.
Installations that used it repoint their GitRepo at this repository, with the paths
`fleet/clusterclasses`, `fleet/identities` and `fleet/clusters`. Each `fleet.yaml` pins its bundle
name and Helm release name to the ones Fleet generated at the old repository root, so Fleet keeps
the existing bundles, releases and clusters.

## Configuration

Settings and pinned versions live in [`config.yml`](ansible/group_vars/all/config.yml),
credentials in `secrets.yml`. Override a setting in the inventory, per host, or with `-e`. These
are the settings most installations change; [docs/configuration.md](docs/configuration.md) lists
every variable.

| Variable | Default | Purpose |
|---|---|---|
| `rancher_hostname` | `ansible_host` if a DNS name, else `rancher.<ip>.sslip.io` | Name Rancher answers on. |
| `rancher_tls_source` | `rancher` | `rancher` (self-signed) or `letsEncrypt`, which needs `rancher_letsencrypt_email`. |
| `rancher_image_tag` | `""` | Development build such as `head` or `v2.15-head`, on the pinned chart. |
| `rancher_ai_enabled` | `true` | Install the Rancher AI agent, MCP server and UI extension. |
| `downstream_clusters` | `[]` | kind clusters to create and import, or RKE2 clusters for Rancher to provision. |
| `fleet_apps` | `[]` | Git repositories Fleet deploys; `fleet_apps_examples` and `fleet_apps_capi_templates` are presets. |
| `helm_charts` | `[]` | Helm charts for the Rancher cluster; presets `helm_charts_monitoring`, `helm_charts_backup`, `helm_charts_kubewarden`, `helm_charts_longhorn`, `helm_charts_harbor`. |
| `capi_providers_enabled` | `false` | Install the CAPI providers for Turtles. |
| `registry_cache_enabled` | `false` | Cache container images on the host. |
| `rke2_etcd_s3_bucket` | `""` | Also upload etcd snapshots to this S3 bucket. |
| `install_docker` | `true` | Install Docker on the host; kind, RKE2 node containers and CAPD need it. |

## Development and CI

```bash
pre-commit install && pre-commit run --all-files
```

Every pull request runs:

- the same hooks, plus OpenTofu validation, tflint and a Trivy scan of `terraform/`, in the
  [Lint workflow](.github/workflows/lint.yml), and zizmor in the
  [Security workflow](.github/workflows/security.yml);
- the [Commits workflow](.github/workflows/commits.yml), which lints every commit against
  [Conventional Commits](https://www.conventionalcommits.org/) and rejects `fixup!` commits;
- the [E2E workflow](.github/workflows/e2e.yml), which deploys the pinned release on the GitHub
  runner with one kind cluster, podinfo as a Fleet app and the image cache, re-runs expecting no
  changes, and checks that Rancher answers, Rancher AI is installed and keeps saved provider
  settings, podinfo runs on both clusters and the clusters pulled through the cache. On pull
  requests that do not touch `ansible/` it skips the deploy and passes, so Renovate's patch
  automerge waits for the deploy only when it matters;
- the Fleet manifests and Fleet platform check workflows for `fleet/`, and Fleet provider sync
  when the provider values change, described in [fleet/README.md](fleet/README.md#development).

E2E also runs every Monday on Rancher `head`, pinned to that build's commit tag so both deploys
use the same image; *Actions → E2E → Run workflow* takes another `rancher_image_tag`. The E2E
badge shows the latest run on `main`, which is that Monday run or a manual one; pull requests
deploy the pinned release. No workflow uses cloud resources.

Required checks: `commits / Conventional commits`, `pre-commit`, the `terraform / ...` jobs,
`zizmor`, `e2e`, `validate` and `platform`. Pull requests merge with merge commits only, so each
commit lands on `main` as written. The [Release workflow](.github/workflows/release.yml) runs
[auto-release](https://github.com/mbologna/auto-release) every Monday at 06:00 UTC and tags a
version when a `feat`, `fix`, `perf`, `revert` or breaking commit landed on `main`. A Renovate
`fix(security)` update, or a manual run, releases at once. Notes are on the
[Releases page](https://github.com/mbologna/rancher-platform/releases).

Licensed under the [Apache License 2.0](LICENSE).
