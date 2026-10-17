# rancher-platform

rancher-platform installs [Rancher](https://www.rancher.com/) on a single Linux host with
Ansible. The playbook sets up RKE2, cert-manager and Rancher, and it is safe to re-run. An
optional OpenTofu (or Terraform) configuration creates the host on AWS.

A fresh deploy takes about seven minutes. A re-run that changes nothing takes about one minute.

## Requirements

- A host with 4 vCPUs, 16 GB of RAM and 100 GB of disk, running openSUSE Leap 16.0, SLES 15 SP7,
  or Ubuntu 22.04 or 24.04. Each was tested on 17 October 2026.
- SSH access to the host as root or as a user with passwordless sudo.
- ansible-core 2.16 or later on your machine.
- For the AWS path: [OpenTofu](https://opentofu.org/) or Terraform 1.6+, and AWS credentials.

## Quick start

1. Create a host on AWS, or skip this step and copy `ansible/inventory/hosts.yml.example` to
   `ansible/inventory/hosts.yml` for your own host.

   ```bash
   cd terraform
   cp terraform.tfvars.example terraform.tfvars   # set your region, SSH key and source CIDRs
   tofu init && tofu apply
   ```

2. Set the Rancher admin password (12 characters or more):

   ```bash
   cd ../ansible
   cp group_vars/all/secrets.yml.example group_vars/all/secrets.yml
   ```

3. Deploy:

   ```bash
   ./manage.sh install
   ./manage.sh deploy
   ```

Rancher then answers at `https://<rancher_hostname>`. Log in as `admin` with the password from
step 2. The kubeconfig is at `~/.kube/rancher-platform.yaml`.

On AWS the hostname defaults to `rancher.<elastic-ip>.sslip.io`, and `tofu apply` writes the
inventory that `manage.sh` uses. The security group admits SSH and the Kubernetes API only from
the CIDRs you set, and ports 80 and 443 from anywhere. The root volume is encrypted with the
account's default EBS key; hosts created before this setting existed are replaced on the next
`tofu apply`.

## Run locally

On a Mac with [Lima](https://lima-vm.io/), `local/lima.sh up` creates an openSUSE Leap 16 VM
with 4 vCPUs, 12 GiB of RAM and a 60 GiB disk, and writes `ansible/inventory/lima.yml`. Rancher
then answers on `rancher.<vm-ip>.sslip.io` from the Mac. Tested on Apple silicon on 17 October
2026.

```bash
./local/lima.sh up
cd ansible && ./manage.sh deploy -i inventory/lima.yml
./local/lima.sh down   # deletes the VM
```

## Commands

Run these from `ansible/`. Extra arguments go to `ansible-playbook`.

| Command | Effect |
|---|---|
| `./manage.sh install` | Installs the pinned Ansible collections. |
| `./manage.sh deploy` | Installs or upgrades everything to the pinned versions. |
| `./manage.sh status` | Shows node, pod and Rancher status. |
| `./manage.sh kubeconfig` | Fetches the kubeconfig to `~/.kube/rancher-platform.yaml`. |
| `./manage.sh uninstall-rancher` | Removes Rancher and cert-manager; RKE2 stays. |
| `./manage.sh reset` | **Deletes all cluster and Docker data** on the host, then deploys. |

## Configuration

Settings and pinned versions live in
[`ansible/group_vars/all/config.yml`](ansible/group_vars/all/config.yml). The common ones:

| Variable | Default | Purpose |
|---|---|---|
| `rancher_hostname` | from inventory | Name Rancher answers on. |
| `rancher_tls_source` | `rancher` | `rancher` (self-signed) or `letsEncrypt`. |
| `rancher_letsencrypt_email` | | Required for `letsEncrypt`. |
| `rke2_ingress_controller` | `traefik` | `traefik` or `ingress-nginx`. |
| `selinux_mode` | `permissive` | `""` leaves SELinux alone. |
| `install_docker` | `true` | Installs Docker on the host. |
| `rke2_etcd_snapshot_schedule` | `0 */12 * * *` | Cron schedule for etcd snapshots; `rke2_etcd_snapshot_retention` keeps 5. |
| `rke2_etcd_s3_bucket` | | Also uploads snapshots to this S3 bucket. |

Let's Encrypt needs `rancher_hostname` to resolve publicly to the host, with port 80 open to
the internet. For example:

```bash
./manage.sh deploy -e rancher_tls_source=letsEncrypt -e rancher_letsencrypt_email=you@example.com
```

To encrypt the password file, run `ansible-vault encrypt group_vars/all/secrets.yml`;
`manage.sh` then asks for the vault password.

Renovate proposes version updates. Patch updates of RKE2, cert-manager and Rancher merge
automatically once the [E2E workflow](.github/workflows/e2e.yml) has deployed them; minor and
major updates wait for review. `deploy` refuses to skip a Kubernetes minor version on an existing host: to go
from RKE2 1.34 to 1.36, deploy once with `-e rke2_version=<a v1.35.x release>` first.

## Back up and restore

RKE2 snapshots etcd, which holds all cluster and Rancher state, to
`/var/lib/rancher/rke2/server/db/snapshots` on the host. Set `rke2_etcd_s3_bucket`, plus keys in
`secrets.yml` if the host has no AWS credentials, to keep copies off the host. To restore, follow
the [RKE2 restore procedure](https://docs.rke2.io/datastore/backup_restore).

## What deploy changes on the host

`deploy` disables firewalld and ufw, sets SELinux to permissive, installs Docker and a Python
virtualenv, writes kernel settings, adds `rancher_hostname` to `/etc/hosts`, and installs RKE2,
`kubectl`, `helm` and helper scripts (`cluster-status`, `rancher-logs`) in `/usr/local/bin`.
It does not remove existing workloads; only `reset` does.

## Remove everything

On AWS, run `tofu destroy` in `terraform/` and delete `~/.kube/rancher-platform.yaml`. On your
own host, run `./manage.sh uninstall-rancher`, then `/usr/local/bin/rke2-uninstall.sh` on the
host to remove RKE2.

## Cluster API (optional)

Rancher includes [Rancher Turtles](https://turtles.docs.rancher.com/). To also install Cluster
API providers, deploy with `-e capi_providers_enabled=true`; add AWS keys to `secrets.yml` for
the AWS provider. `-e fleet_gitrepo_enabled=true` registers example cluster definitions from
[rancher-fleet-clusters](https://github.com/mbologna/rancher-fleet-clusters).

## Development

```bash
pre-commit install
pre-commit run --all-files
```

The hooks run yamllint, shellcheck, ansible-lint, actionlint, `tofu fmt` and tflint; the
[Lint workflow](.github/workflows/lint.yml) runs them on every pull request.

On pull requests that change `ansible/`, the [E2E workflow](.github/workflows/e2e.yml) deploys the
platform on the GitHub runner itself, deploys again expecting no changes, and checks that Rancher
answers. It uses no cloud resources.

The [Security workflow](.github/workflows/security.yml) scans the Terraform with trivy and the
workflows with zizmor, and reports findings under Security > Code scanning.

Pull request titles follow [Conventional Commits](https://www.conventionalcommits.org/) because
squash merges turn them into commit messages. The [Release workflow](.github/workflows/release.yml)
keeps a release pull request open with the next version and `CHANGELOG.md`; merging it tags the
release.

Licensed under the [Apache License 2.0](LICENSE).
