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
the CIDRs you set, and ports 80 and 443 from anywhere.

## Commands

Run these from `ansible/`. Extra arguments go to `ansible-playbook`.

| Command | Effect |
|---|---|
| `./manage.sh install` | Installs the pinned Ansible collections. |
| `./manage.sh deploy` | Installs or upgrades everything to the pinned versions. |
| `./manage.sh status` | Shows node, pod and Rancher status. |
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

Let's Encrypt needs `rancher_hostname` to resolve publicly to the host, with port 80 open to
the internet. For example:

```bash
./manage.sh deploy -e rancher_tls_source=letsEncrypt -e rancher_letsencrypt_email=you@example.com
```

To encrypt the password file, run `ansible-vault encrypt group_vars/all/secrets.yml`;
`manage.sh` then asks for the vault password.

Renovate proposes version updates. RKE2, cert-manager and Rancher updates are never merged
automatically.

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
[Lint workflow](.github/workflows/lint.yml) runs them on every pull request. The
[Deploy test workflow](.github/workflows/deploy-test.yml) creates a host, deploys twice and
destroys it. It needs an AWS role ARN in the `AWS_ROLE_ARN` secret.

Licensed under the [Apache License 2.0](LICENSE).
