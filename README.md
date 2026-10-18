# rancher-platform

[![E2E](https://github.com/mbologna/rancher-platform/actions/workflows/e2e.yml/badge.svg)](https://github.com/mbologna/rancher-platform/actions/workflows/e2e.yml)
[![Lint](https://github.com/mbologna/rancher-platform/actions/workflows/lint.yml/badge.svg)](https://github.com/mbologna/rancher-platform/actions/workflows/lint.yml)
[![Release](https://img.shields.io/github/v/release/mbologna/rancher-platform)](https://github.com/mbologna/rancher-platform/releases)

Install [Rancher](https://www.rancher.com/) on one Linux host with Ansible, in about seven
minutes.

- **Any Linux host you can SSH into.** The playbook installs RKE2, cert-manager and Rancher, and
  is safe to re-run.
- **No host?** OpenTofu creates one on AWS, or Lima creates a local VM.
- **Clusters to manage.** Optionally, the playbook creates kind clusters on the same host and
  imports them into Rancher.

## Quick start

On your machine you need ansible-core 2.16 or later.

```bash
cd ansible
cp inventory/hosts.yml.example inventory/hosts.yml           # ansible_host, rancher_hostname
cp group_vars/all/secrets.yml.example group_vars/all/secrets.yml   # admin password, 12+ chars
./manage.sh install                                          # pinned Ansible collections
./manage.sh deploy
```

Open `https://<rancher_hostname>` and log in as `admin`. `kubectl` works straight away with
`~/.kube/rancher-platform.yaml`.

`rancher.<ip>.sslip.io` works as a hostname without DNS. To encrypt the password file, run
`ansible-vault encrypt group_vars/all/secrets.yml`; `manage.sh` then asks for the vault password.

## Host requirements

| | |
|---|---|
| OS | openSUSE Leap 16.0, SLES 15 SP7, Ubuntu 22.04 or 24.04 (tested 17 October 2026) |
| Size | 4 vCPUs, 16 GB RAM, 100 GB disk; about 1 GB more RAM per downstream cluster |
| Access | SSH as root or as a user with passwordless sudo |
| Network | Ports 80 and 443 reachable from your browser |

`deploy` stops before changing anything if the host already runs RKE2 or K3s installed by other
means, or if another service holds port 80, 443, 6443, 9345 or 10250. `./manage.sh reset`
clears such a host.

## No host? Create one

### On AWS

`terraform/` creates a `t3.xlarge` openSUSE Leap 16.0 instance with a 100 GB encrypted disk and
an Elastic IP. It needs [OpenTofu](https://opentofu.org/) or Terraform 1.6+ and AWS credentials.

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # region, SSH key, allowed source CIDRs
tofu init && tofu apply
```

`tofu apply` writes the Ansible inventory, with Rancher on `rancher.<elastic-ip>.sslip.io`.
Continue with the Quick start, skipping the `hosts.yml` line. SSH and the Kubernetes API are open
only to your CIDRs; ports 80 and 443 are open to all. `tofu destroy` removes everything.

### On your Mac

[Lima](https://lima-vm.io/) runs an openSUSE Leap 16 VM (4 vCPUs, 12 GiB RAM, 60 GiB disk),
reachable from the Mac. Tested on Apple silicon.

```bash
./local/lima.sh up                                       # writes ansible/inventory/lima.yml
cd ansible && ./manage.sh deploy -i inventory/lima.yml
./local/lima.sh down                                     # deletes the VM
```

## Downstream clusters

```bash
./manage.sh deploy -e '{"downstream_clusters": ["dev", "staging"]}'
```

Each name becomes a kind cluster `rp-<name>` on the host, imported into Rancher and ready when
`deploy` finishes. Drop a name and deploy again to delete that cluster; clusters `deploy` did not
create are left alone. Set `downstream_clusters` in
[`config.yml`](ansible/group_vars/all/config.yml) to keep the list.

## Kubeconfig

`~/.kube/rancher-platform.yaml` has one context per cluster, reached through Rancher on port 443:
`<host>` for the Rancher cluster and `<host>-<name>` for each downstream cluster, where `<host>`
is the inventory name. Files from several hosts merge without clashes; `kubeconfig_context_name`
changes the prefix.

The file holds an `admin` token valid for 30 days. `./manage.sh kubeconfig` issues a new one and
revokes the old. If you change the `admin` password in the UI, set `rancher_admin_password` in
`secrets.yml`; otherwise `deploy` falls back to the RKE2 kubeconfig on port 6443.

## Commands

Run from `ansible/`. Extra arguments go to `ansible-playbook`.

| Command | Effect |
|---|---|
| `./manage.sh install` | Install the pinned Ansible collections. |
| `./manage.sh deploy` | Install or upgrade everything to the pinned versions. |
| `./manage.sh status` | Show node, pod and Rancher status. |
| `./manage.sh kubeconfig` | Write a new kubeconfig and revoke the old one. |
| `./manage.sh uninstall-rancher` | Remove Rancher and cert-manager; RKE2 and downstream clusters stay. The next `deploy` re-imports them. |
| `./manage.sh reset` | **Delete all cluster and Docker data** on the host, including RKE2, K3s, kind and k3d installed by anything, then deploy. |

## Configuration

Settings and pinned versions live in
[`ansible/group_vars/all/config.yml`](ansible/group_vars/all/config.yml).

| Variable | Default | Purpose |
|---|---|---|
| `rancher_tls_source` | `rancher` | `rancher` (self-signed) or `letsEncrypt`; the latter needs `rancher_letsencrypt_email`, public DNS and port 80 open to the internet. |
| `downstream_clusters` | `[]` | kind clusters to create and import. |
| `rke2_ingress_controller` | `traefik` | `traefik` or `ingress-nginx`. |
| `selinux_mode` | `permissive` | `""` leaves SELinux alone. |
| `install_docker` | `true` | Install Docker on the host. |
| `rke2_etcd_snapshot_schedule` | `0 */12 * * *` | etcd snapshot schedule; `rke2_etcd_snapshot_retention` keeps 5. |
| `rke2_etcd_s3_bucket` | | Also upload snapshots to S3. |
| `capi_providers_enabled` | `false` | Install Cluster API providers for [Rancher Turtles](https://turtles.docs.rancher.com/); AWS keys in `secrets.yml` enable CAPA. |
| `fleet_gitrepo_enabled` | `false` | Register cluster definitions from [rancher-fleet-clusters](https://github.com/mbologna/rancher-fleet-clusters). |

## Operations

**Upgrades.** Renovate proposes version bumps. Patch releases of RKE2, cert-manager and Rancher
merge once the E2E workflow has deployed them; minor and major ones wait for review. Run
`./manage.sh deploy` to apply. `deploy` refuses to skip a Kubernetes minor: go from 1.34 to 1.36
via `-e rke2_version=<a v1.35.x release>`.

**Backups.** RKE2 snapshots etcd, which holds all cluster and Rancher state, to
`/var/lib/rancher/rke2/server/db/snapshots`. Set `rke2_etcd_s3_bucket` to keep copies off the
host. Restore with the [RKE2 procedure](https://docs.rke2.io/datastore/backup_restore).

**Removal.** On AWS, `tofu destroy`. On your own host, `./manage.sh uninstall-rancher`, then on
the host `kind delete clusters --all` and `/usr/local/bin/rke2-uninstall.sh`.

**Host changes.** `deploy` disables firewalld and ufw, sets SELinux to permissive, installs
Docker, a Python virtualenv, RKE2, `kubectl`, `helm` and helper scripts (`cluster-status`,
`rancher-logs`), writes kernel settings and adds `rancher_hostname` to `/etc/hosts`. Only `reset`
removes existing workloads.

## Development

```bash
pre-commit install && pre-commit run --all-files
```

Every pull request runs the same hooks in the [Lint workflow](.github/workflows/lint.yml), plus
trivy and zizmor in the [Security workflow](.github/workflows/security.yml). Pull requests that
touch `ansible/` also run the [E2E workflow](.github/workflows/e2e.yml): it deploys with one
downstream cluster on the GitHub runner, re-runs expecting no changes and checks that Rancher
answers. No workflow uses cloud resources.

Pull request titles follow [Conventional Commits](https://www.conventionalcommits.org/); the
[Release workflow](.github/workflows/release.yml) turns them into `CHANGELOG.md` and version tags.

Licensed under the [Apache License 2.0](LICENSE).
