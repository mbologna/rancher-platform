# rancher-platform

Install [Rancher](https://www.rancher.com/) on one Linux host with Ansible. If you have no
host, OpenTofu creates one on AWS. Optionally, downstream clusters are created and imported.

The playbook installs RKE2, cert-manager and Rancher on a host you already have, and it is safe
to re-run. If you have no suitable host, an OpenTofu configuration creates one on AWS. The
playbook can also create kind clusters on the same host and register them in Rancher, so there
are clusters to manage straight away.

A fresh deploy takes about seven minutes. A re-run that changes nothing takes about one minute.

## What you need

A Linux host with:

- openSUSE Leap 16.0, SLES 15 SP7, or Ubuntu 22.04 or 24.04 (each tested on 17 October 2026);
- 4 vCPUs, 16 GB of RAM and 100 GB of disk, plus about 1 GB of RAM per downstream cluster;
- SSH access as root or as a user with passwordless sudo;
- ports 80 and 443 reachable from where you open Rancher;
- a hostname for Rancher that resolves to the host. `rancher.<ip>.sslip.io` works without DNS.

`deploy` stops before changing anything if the host already runs RKE2 or K3s installed by other
means, or if another service holds port 80, 443, 6443, 9345 or 10250.
[`reset`](#commands) clears such a host.

On your machine you need ansible-core 2.16 or later.

No host? [Create one on AWS](#create-a-host-on-aws) or [run a local VM](#run-a-local-vm).

## Install Rancher

1. Describe the host:

   ```bash
   cd ansible
   cp inventory/hosts.yml.example inventory/hosts.yml   # set ansible_host and rancher_hostname
   ```

2. Set the Rancher admin password (12 characters or more):

   ```bash
   cp group_vars/all/secrets.yml.example group_vars/all/secrets.yml
   ```

3. Deploy:

   ```bash
   ./manage.sh install   # pinned Ansible collections
   ./manage.sh deploy
   ```

Rancher then answers at `https://<rancher_hostname>`. Log in as `admin` with the password from
step 2. Your [kubeconfig](#kubeconfig) is at `~/.kube/rancher-platform.yaml`.

To encrypt the password file, run `ansible-vault encrypt group_vars/all/secrets.yml`;
`manage.sh` then asks for the vault password.

## Create a host on AWS

The configuration in `terraform/` creates a `t3.xlarge` instance running openSUSE Leap 16.0,
with a 100 GB encrypted root volume and an Elastic IP. It needs
[OpenTofu](https://opentofu.org/) or Terraform 1.6 or later, and AWS credentials.

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # region, SSH key and source CIDRs
tofu init && tofu apply
```

`tofu apply` writes the inventory that `manage.sh` uses, with `rancher_hostname` set to
`rancher.<elastic-ip>.sslip.io`. Skip step 1 of [Install Rancher](#install-rancher) and continue
with step 2. The security group admits SSH and the Kubernetes API only from the CIDRs you set,
and ports 80 and 443 from anywhere.

## Run a local VM

On a Mac with [Lima](https://lima-vm.io/), `local/lima.sh up` creates an openSUSE Leap 16 VM
with 4 vCPUs, 12 GiB of RAM and a 60 GiB disk, and writes `ansible/inventory/lima.yml`.
Rancher then answers on `rancher.<vm-ip>.sslip.io` from the Mac. Tested on Apple silicon on
17 October 2026.

```bash
./local/lima.sh up
cd ansible && ./manage.sh deploy -i inventory/lima.yml
./local/lima.sh down   # deletes the VM
```

## Add downstream clusters

List cluster names in `downstream_clusters`:

```bash
./manage.sh deploy -e '{"downstream_clusters": ["dev", "staging"]}'
```

For each name, `deploy` creates a kind cluster `rp-<name>` on the host, imports it into Rancher
and waits until Rancher reports it ready. The clusters need Docker, which `deploy` installs.
Inside them, CoreDNS resolves `rancher_hostname` to the host's private address, so the agents
reach Rancher without leaving the host.

Removing a name and deploying again deletes that cluster from Rancher and kind. Clusters that
`deploy` did not create are left alone. To keep the list, set `downstream_clusters` in
[`config.yml`](ansible/group_vars/all/config.yml).

## Kubeconfig

`deploy` writes `~/.kube/rancher-platform.yaml` with one context per cluster: the inventory host
name (for example `leto`) for the Rancher host and `<host>-<name>` for each downstream cluster.
Set `kubeconfig_context_name` to choose another prefix; distinct prefixes let you merge the files
of several hosts.

Every context goes through Rancher on port 443 (`https://<rancher_hostname>/k8s/clusters/<id>`),
so the file works from networks that block port 6443. It holds an `admin` token that expires
after 30 days. `./manage.sh kubeconfig` replaces it and revokes the old one; `deploy` also
replaces it when the clusters or Rancher's CA change.

`deploy` logs in with `rancher_bootstrap_password`. If you change the `admin` password in the
UI, set `rancher_admin_password` in `secrets.yml`; without it, `deploy` falls back to the direct
RKE2 kubeconfig on port 6443. Set `kubeconfig_via_rancher: false` to always use that file.

## Commands

Run these from `ansible/`. Extra arguments go to `ansible-playbook`.

| Command | Effect |
|---|---|
| `./manage.sh install` | Installs the pinned Ansible collections. |
| `./manage.sh deploy` | Installs or upgrades everything to the pinned versions. |
| `./manage.sh status` | Shows node, pod and Rancher status. |
| `./manage.sh kubeconfig` | Writes a new kubeconfig and revokes the old one. |
| `./manage.sh uninstall-rancher` | Removes Rancher and cert-manager; RKE2 and downstream clusters stay. |
| `./manage.sh reset` | **Deletes all cluster and Docker data** on the host, then deploys. Removes RKE2, K3s, kind and k3d, whoever installed them. |

After `uninstall-rancher`, the next `deploy` installs Rancher with a new self-signed CA. The
downstream agents reject it, so `deploy` imports the clusters again and Rancher redeploys their
agents.

## Configuration

Settings and pinned versions live in
[`ansible/group_vars/all/config.yml`](ansible/group_vars/all/config.yml). The common ones:

| Variable | Default | Purpose |
|---|---|---|
| `rancher_hostname` | from inventory | Name Rancher answers on. |
| `rancher_tls_source` | `rancher` | `rancher` (self-signed) or `letsEncrypt`. |
| `rancher_letsencrypt_email` | | Required for `letsEncrypt`. |
| `downstream_clusters` | `[]` | Names of kind clusters to create and import into Rancher. |
| `rke2_ingress_controller` | `traefik` | `traefik` or `ingress-nginx`. |
| `selinux_mode` | `permissive` | `""` leaves SELinux alone. |
| `install_docker` | `true` | Installs Docker on the host. |
| `rke2_etcd_snapshot_schedule` | `0 */12 * * *` | Cron schedule for etcd snapshots; `rke2_etcd_snapshot_retention` keeps 5. |
| `rke2_etcd_s3_bucket` | | Also uploads snapshots to this S3 bucket. |

Let's Encrypt needs `rancher_hostname` to resolve publicly to the host, with port 80 open to the
internet:

```bash
./manage.sh deploy -e rancher_tls_source=letsEncrypt -e rancher_letsencrypt_email=you@example.com
```

## Upgrades

Renovate proposes version updates. Patch updates of RKE2, cert-manager and Rancher merge
automatically once the [E2E workflow](.github/workflows/e2e.yml) has deployed them; minor and
major updates wait for review. Run `./manage.sh deploy` to apply them.

`deploy` refuses to skip a Kubernetes minor version on an existing host. To go from RKE2 1.34 to
1.36, deploy once with `-e rke2_version=<a v1.35.x release>` first.

## Back up and restore

RKE2 snapshots etcd, which holds all cluster and Rancher state, to
`/var/lib/rancher/rke2/server/db/snapshots` on the host. Set `rke2_etcd_s3_bucket`, plus keys in
`secrets.yml` if the host has no AWS credentials, to keep copies off the host. To restore, follow
the [RKE2 restore procedure](https://docs.rke2.io/datastore/backup_restore).

## What deploy changes on the host

`deploy` disables firewalld and ufw, sets SELinux to permissive, installs Docker and a Python
virtualenv, writes kernel settings, adds `rancher_hostname` to `/etc/hosts`, and installs RKE2,
`kubectl`, `helm` and helper scripts (`cluster-status`, `rancher-logs`) in `/usr/local/bin`. It
also sets Rancher's server URL, which Rancher otherwise leaves empty until the first UI login and
without which it cannot import clusters. Only `reset` removes existing workloads.

## Remove everything

On AWS, run `tofu destroy` in `terraform/`. On your own host, run `./manage.sh uninstall-rancher`,
then on the host run `kind delete clusters --all` if you created downstream clusters, and
`/usr/local/bin/rke2-uninstall.sh` to remove RKE2. Finally delete `~/.kube/rancher-platform.yaml`.

## Cluster API

Rancher includes [Rancher Turtles](https://turtles.docs.rancher.com/). To also install Cluster
API providers, deploy with `-e capi_providers_enabled=true`; add AWS keys to `secrets.yml` for the
AWS provider. `-e fleet_gitrepo_enabled=true` registers example cluster definitions from
[rancher-fleet-clusters](https://github.com/mbologna/rancher-fleet-clusters).

## Development

```bash
pre-commit install
pre-commit run --all-files
```

The hooks run yamllint, shellcheck, ansible-lint, actionlint, `tofu fmt` and tflint; the
[Lint workflow](.github/workflows/lint.yml) runs them on every pull request.

On pull requests that change `ansible/`, the [E2E workflow](.github/workflows/e2e.yml) deploys
the platform with one downstream cluster on the GitHub runner itself, deploys again expecting no
changes, and checks that Rancher answers. It uses no cloud resources. The
[Security workflow](.github/workflows/security.yml) scans the Terraform with trivy and the
workflows with zizmor.

Pull request titles follow [Conventional Commits](https://www.conventionalcommits.org/) because
squash merges turn them into commit messages. The [Release workflow](.github/workflows/release.yml)
keeps a release pull request open with the next version and `CHANGELOG.md`; merging it tags the
release.

Licensed under the [Apache License 2.0](LICENSE).
