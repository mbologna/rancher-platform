# rancher-platform

[![E2E](https://github.com/mbologna/rancher-platform/actions/workflows/e2e.yml/badge.svg)](https://github.com/mbologna/rancher-platform/actions/workflows/e2e.yml)
[![Lint](https://github.com/mbologna/rancher-platform/actions/workflows/lint.yml/badge.svg)](https://github.com/mbologna/rancher-platform/actions/workflows/lint.yml)
[![Version](https://img.shields.io/github/v/tag/mbologna/rancher-platform?label=version)](https://github.com/mbologna/rancher-platform/tags)

Install [Rancher](https://www.rancher.com/) on one Linux host with Ansible, in about seven
minutes. If you have no host, create one on AWS or on your Mac first. Optionally, give Rancher
some clusters to manage straight away.

The steps below go from a bare host to a running Rancher. Run the commands from the repository
root unless noted; all of them are safe to re-run. Everything else is in the
[feature guides](#features).

## 1. Get a host

You need a Linux host you can SSH into as root or as a user with passwordless sudo, with:

- openSUSE Leap 16.0, SLES 15 SP7, or Ubuntu 22.04 or 24.04 (tested on 17 October 2026);
- 4 vCPUs, 16 GB RAM and 100 GB disk, plus about 1 GB RAM per kind cluster and 2 GB per
  provisioned node;
- ports 80 and 443 reachable from your browser.

Then pick one:

- **A host you have.** Copy the inventory and set the host's address. Rancher answers on that
  name if it is a DNS name, or on `rancher.<ip>.sslip.io` if it is an IP address; set
  `rancher_hostname` to use another name.

  ```bash
  cp ansible/inventory/hosts.yml.example ansible/inventory/hosts.yml   # ansible_host
  ```

- **A new host on AWS.** `terraform/` creates a `t3.xlarge` openSUSE Leap 16.0 instance with a
  100 GB encrypted disk and an Elastic IP, and writes the inventory for you, with Rancher on
  `rancher.<elastic-ip>.sslip.io`. SSH and the Kubernetes API are open only to the CIDRs you set.
  You need [OpenTofu](https://opentofu.org/) or Terraform 1.6+ and AWS credentials.

  ```bash
  cp terraform/terraform.tfvars.example terraform/terraform.tfvars   # region, SSH key, source CIDRs
  tofu -chdir=terraform init && tofu -chdir=terraform apply
  ```

- **A VM on your Mac.** [Lima](https://lima-vm.io/) starts an openSUSE Leap 16 VM (4 vCPUs,
  12 GiB RAM, 60 GiB disk) and writes `ansible/inventory/lima.yml`; add `-i inventory/lima.yml`
  to the commands below.

  ```bash
  ./local/lima.sh up
  ```

## 2. Install Rancher

You need ansible-core 2.16 or later on your machine. Set the Rancher admin password (12+
characters), then deploy:

```bash
cd ansible
cp group_vars/all/secrets.yml.example group_vars/all/secrets.yml
./manage.sh install   # pinned Ansible collections
./manage.sh deploy
```

The remaining `./manage.sh` commands also run from `ansible/`; the
[command reference](docs/reference.md#commands) lists them all.

`deploy` installs RKE2, cert-manager, Rancher and [Rancher AI](docs/rancher-ai.md). Open
`https://<rancher_hostname>` and log in as `admin`. To encrypt the password file, run
`ansible-vault encrypt group_vars/all/secrets.yml`; `manage.sh` then asks for the vault password.
`./manage.sh status` shows the nodes, the Rancher clusters, the Fleet apps and any pod that is
not running.

`deploy` changes host settings such as the firewall, SELinux and `/etc/hosts`; see
[what deploy changes on the host](docs/reference.md#what-deploy-changes-on-the-host). It stops
before changing anything if the host already runs RKE2 or K3s installed by other means, or if
another service holds port 80, 443, 6443, 9345 or 10250. `./manage.sh reset` wipes such a host
and deploys.

## 3. Use the clusters

`deploy` writes `~/.kube/rancher-platform.yaml`, with one context per cluster, all reached
through Rancher on port 443:

```bash
export KUBECONFIG=~/.kube/rancher-platform.yaml
kubectl config get-contexts   # <host>, <host>-dev, <host>-staging
```

`<host>` is the inventory name, so files from several hosts merge without clashes;
`kubeconfig_context_name` changes it. The file holds an `admin` token valid for 30 days.
`./manage.sh kubeconfig` issues a new one and revokes the old. If you change the `admin`
password in the UI, set `rancher_admin_password` in `secrets.yml`; otherwise `deploy` falls back
to the RKE2 kubeconfig on port 6443.

## 4. Tear it down

| Host from | Command |
|---|---|
| AWS | `tofu -chdir=terraform destroy` |
| Lima | `./local/lima.sh down` |
| Your own | `./manage.sh deploy -e '{"downstream_clusters": []}'`, `./manage.sh uninstall-rancher`, then on the host `/usr/local/bin/rke2-uninstall.sh` |

`uninstall-rancher` keeps RKE2 and the downstream clusters; see the
[command reference](docs/reference.md#commands) for what a reinstall brings back.

## Features

Optional features are turned on in [`config.yml`](ansible/group_vars/all/config.yml) or with
`-e` on `deploy`. For example, two kind clusters imported into Rancher:

```bash
./manage.sh deploy -e '{"downstream_clusters": ["dev", "staging"]}'
```

| Feature | What it gives you |
|---|---|
| [Downstream clusters](docs/downstream-clusters.md) | kind clusters imported into Rancher, or RKE2 clusters Rancher provisions on Docker nodes. |
| [Fleet apps](docs/fleet-apps.md) | Apps from Git repositories on every cluster, with four samples and an Ingress per app. |
| [Helm charts](docs/helm-charts.md) | Charts on the Rancher cluster; presets for Monitoring, Backups, Kubewarden, Longhorn and Harbor. |
| [Rancher AI](docs/rancher-ai.md) | Liz, the Rancher AI Assistant. On by default. |
| [Upgrades and development builds](docs/upgrades.md) | Upgrades proposed by Renovate; release candidates, alphas and nightly `head` images. |
| [Snapshots and restore](docs/snapshots.md) | etcd snapshots every 12 hours and on demand, optionally to S3, and roll-back. On by default. |
| [Registry cache](docs/registry-cache.md) | A pull-through image cache on the host for RKE2 and the kind clusters. |
| [Cluster API](docs/fleet-apps.md#cluster-api) | Rancher Turtles providers, with ClusterClasses and example clusters. |

The [reference](docs/reference.md) lists every command and setting. To contribute, see
[development](docs/development.md).

Licensed under the [Apache License 2.0](LICENSE).
