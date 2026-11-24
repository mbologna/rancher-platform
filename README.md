# rancher-platform

[![E2E](https://github.com/mbologna/rancher-platform/actions/workflows/e2e.yml/badge.svg)](https://github.com/mbologna/rancher-platform/actions/workflows/e2e.yml)
[![Lint](https://github.com/mbologna/rancher-platform/actions/workflows/lint.yml/badge.svg)](https://github.com/mbologna/rancher-platform/actions/workflows/lint.yml)
[![Version](https://img.shields.io/github/v/tag/mbologna/rancher-platform?label=version)](https://github.com/mbologna/rancher-platform/tags)

rancher-platform deploys a [Rancher](https://www.rancher.com/) management cluster on one Linux
host in about seven minutes. Ansible installs RKE2 (Kubernetes v1.36), cert-manager and Rancher
2.15 on a host you have, on an EC2 instance that OpenTofu creates, or on a Lima VM on a Mac.
Rancher answers at `rancher.<ip>.sslip.io` or a name you choose, with a self-signed or Let's
Encrypt certificate, and `deploy` writes one kubeconfig with a context per cluster.

The same playbook can also:

- import kind clusters into Rancher, or have Rancher provision RKE2 clusters on Docker
  containers
- deploy apps from Git repositories to every cluster with Fleet
- install Cluster API providers for Rancher Turtles, with ClusterClasses and example clusters
  on Docker, AWS and EKS
- install Liz, the Rancher AI Assistant (on by default)
- install Monitoring, Backups, Kubewarden, Longhorn, Harbor or any other Helm chart on the
  Rancher cluster
- take etcd snapshots every 12 hours, upload them to S3 and restore from them (on by default)
- upgrade RKE2 one minor at a time and Rancher with a snapshot first, or run release
  candidates, alphas and nightly builds
- run a pull-through image cache for RKE2 and the downstream clusters

[Features](#features) links to a page for each. Versions are pinned in
[`config.yml`](ansible/group_vars/all/config.yml) and [`fleet/platform/`](fleet/platform/), and
Renovate updates them.

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
   `rp-<name>` imported into Rancher; the [features](#features) cover RKE2 clusters provisioned
   by Rancher, Fleet apps, Helm charts and Cluster API. Set the lists in `config.yml` to keep
   them.

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

[docs/operations.md](docs/operations.md) lists every `./manage.sh` command and covers the
kubeconfig, tearing down and troubleshooting.

## Features

Turn a feature on in [`config.yml`](ansible/group_vars/all/config.yml), per host in the
inventory, or for one run with `-e`. Each page explains the settings, caveats and what was tested.

| Feature | What it gives you | Default |
|---|---|---|
| [Rancher AI](docs/rancher-ai.md) | Liz, the Rancher AI Assistant: agent, MCP server and UI extension; you configure the LLM in the UI. | on |
| [Downstream clusters](docs/downstream-clusters.md) | kind clusters imported into Rancher, or RKE2 clusters that Rancher provisions on Docker containers to test custom-cluster provisioning. | off |
| [Fleet apps](docs/fleet-apps.md) | Apps from Git repositories on every cluster, four samples, and Ingresses at `http://<app>.<ip>.sslip.io`. | off |
| [Cluster API](docs/cluster-api.md) | CAPI providers for [Rancher Turtles](https://turtles.docs.rancher.com/), with ClusterClasses and example clusters on Docker, AWS and EKS in [`fleet/`](fleet/README.md); the preferred way to run RKE2 on Docker. | off |
| [Helm charts](docs/helm-charts.md) | Charts on the Rancher cluster; presets for Monitoring, Backups, Kubewarden, Longhorn and Harbor. | off |
| [Snapshots and restore](docs/snapshots.md) | etcd snapshots every 12 hours and on demand, optional S3 upload, and restore. | on |
| [Upgrades and development builds](docs/upgrades.md) | Guarded upgrades with a snapshot first; release candidates, alphas and nightly `head` builds. | |
| [Image cache](docs/image-cache.md) | A pull-through cache on the host for RKE2 and the downstream clusters. | off |

[docs/configuration.md](docs/configuration.md) lists every setting and credential.
[docs/development.md](docs/development.md) covers pre-commit, CI, releases and how to document
a new feature.

## Why not an existing tool

- [tf-rancher-up](https://github.com/rancher/tf-rancher-up) (Rancher's Terraform modules)
  provisions cloud VMs with RKE2 or k3s plus Rancher, with Longhorn and backup add-ons. It
  can't install on a host you have or a Lima VM.
- It has no kind import, no RKE2 clusters provisioned on Docker, and no Turtles and Cluster API
  with ClusterClasses.
- It has no Rancher AI, no etcd snapshot restore, no stepwise upgrades and no image cache.
- [quickstart](https://github.com/rancher-archives/quickstart) (Rancher's quick start
  Terraform) is archived.

Checked 2026-11-23.

## Versioning

Tags are this project's own SemVer with the Rancher version it deploys as build metadata:
`v2.2.0+up2.15.3` deploys Rancher 2.15.3. The version follows the commits, and a Rancher minor
is a breaking change, so `v3.0.0+up2.16.0` would follow. A Rancher patch alone releases a patch.
Check out a tag to deploy exactly that combination. See the
[versioning standard](https://github.com/mbologna/.github/blob/main/VERSIONING.md); every
release since `v1.0.0+up2.15.2` carries the metadata.

Licensed under the [Apache License 2.0](LICENSE).
