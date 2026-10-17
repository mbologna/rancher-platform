# rancher-platform

rancher-platform installs a single-node Rancher management cluster (RKE2, cert-manager and
Rancher) on one Linux host with Ansible. Rancher v2.14 and later bundles
[Rancher Turtles](https://turtles.docs.rancher.com/), so the result is ready to provision
downstream clusters with [Cluster API (CAPI)](https://cluster-api.sigs.k8s.io/).

An optional OpenTofu (or Terraform) configuration creates a suitable EC2 instance. CAPI
providers, ClusterClasses and cluster definitions live in
[rancher-fleet-clusters](https://github.com/mbologna/rancher-fleet-clusters).

A fresh deploy takes about seven minutes on a `t3.xlarge`. A re-run that changes nothing takes
about one minute.

## Supported hosts

Each OS was deployed, re-deployed with `changed=0` and checked on `/ping` on 17 October 2026.

| OS | Notes |
|---|---|
| openSUSE Leap 16.0 | Terraform default. SELinux is set to permissive (`selinux_mode`). |
| SLES 15 SP7 | Ansible enables the SLE Python 3 module with `suseconnect` and installs Python 3.11. |
| Ubuntu 24.04, 22.04 | |

openSUSE Leap 15.x should behave like SLES 15 but was not tested: AWS no longer carries Leap 15
images. The host needs 4 vCPUs, 16 GB of RAM and 100 GB of disk; the Terraform default is a
`t3.xlarge` (about $0.18 an hour in `eu-west-1`) with a 100 GB volume.

## Prerequisites

On your machine:

- ansible-core 2.16 or later. The Kubernetes Python client is not needed locally: the
  Kubernetes modules run on the host, in a virtualenv the playbook creates.
- SSH access to the host as root or as a user with passwordless sudo.
- For the AWS path: [OpenTofu](https://opentofu.org/) 1.6+ or Terraform 1.6+, and AWS
  credentials.

## Create a host on AWS (optional)

Skip this if you already have a host.

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# set aws_region, public_key_path, allowed_ssh_cidrs and allowed_admin_cidrs
tofu init
tofu apply
```

This creates a VPC (or a subnet in `existing_vpc_id`), a security group, an openSUSE Leap 16.0
instance and an Elastic IP. `allowed_ssh_cidrs` and `allowed_admin_cidrs` are required and
reject `0.0.0.0/0`. Rancher's hostname defaults to `rancher.<elastic-ip>.sslip.io`; set
`rancher_hostname` to use your own DNS name.

| Port | Source | Purpose |
|---|---|---|
| 22/tcp | `allowed_ssh_cidrs` | SSH |
| 80/tcp, 443/tcp | anywhere | Rancher UI and API, cluster registration, ACME HTTP-01 |
| 6443/tcp | `allowed_admin_cidrs`, `allowed_cluster_cidrs` | Kubernetes API |
| 9345/tcp | `allowed_cluster_cidrs` | RKE2 supervisor |
| 30000–32767/tcp | `allowed_cluster_cidrs` | NodePort services |
| 8472/udp | `allowed_cluster_cidrs` | VXLAN overlay |

`tofu apply` writes an Ansible inventory to `terraform/generated/hosts.yml`. `manage.sh` uses it
when `ansible/inventory/hosts.yml` does not exist.

To keep state in S3 with locking, copy `terraform/backend.tf.example` to `terraform/backend.tf`,
set the bucket, and run `tofu init -migrate-state`.

## Install Rancher

1. Point Ansible at the host (skip this if you used Terraform):

   ```bash
   cp ansible/inventory/hosts.yml.example ansible/inventory/hosts.yml
   # set ansible_host, ansible_user and rancher_hostname
   ```

2. Set the Rancher admin password (12 characters or more):

   ```bash
   cd ansible
   cp group_vars/all/secrets.yml.example group_vars/all/secrets.yml
   ```

   To encrypt it, run `ansible-vault encrypt group_vars/all/secrets.yml`. `manage.sh` then asks
   for the vault password, unless `ANSIBLE_VAULT_PASSWORD_FILE` is set. Both `hosts.yml` and
   `secrets.yml` are gitignored.

3. Install the collections and deploy:

   ```bash
   ./manage.sh install
   ./manage.sh deploy
   ```

When `deploy` finishes:

- Rancher answers at `https://<rancher_hostname>`; log in as `admin` with the bootstrap password.
- The kubeconfig is at `~/.kube/rancher-platform.yaml` on your machine, and at `~/.kube/config`
  for the SSH user on the host.
- The Turtles controller is running.

To install CAPI providers and example clusters, register rancher-fleet-clusters in Fleet, either
by following that repository's README or with
`./manage.sh deploy -e fleet_gitrepo_enabled=true`.

### Commands

| Command | Effect |
|---|---|
| `install` | Installs the collections pinned in `requirements.yml`. |
| `deploy` | Installs or upgrades RKE2, Helm, cert-manager and Rancher to the pinned versions. Safe to re-run. |
| `reset` | **Destroys data.** Removes RKE2, k3s, kind and k3d, prunes all Docker data, then deploys. |
| `status` | Runs `cluster-status` on every host. |
| `uninstall-rancher` | Removes Rancher and cert-manager. RKE2 stays; `deploy` reinstalls them. |

Further arguments go to `ansible-playbook`, for example
`./manage.sh deploy -i other.yml -e rke2_ingress_controller=traefik`.

### Changes made to the host

`deploy` does not remove existing workloads; only `reset` does. It does change the host:

- stops and disables firewalld and ufw;
- sets SELinux to `selinux_mode` (permissive by default) when SELinux is enabled;
- installs Docker (`install_docker`), and a Python virtualenv in `/opt/rancher-platform/venv`;
- writes kernel settings to `/etc/sysctl.d/99-rancher-platform.conf`;
- maps `rancher_hostname` to the host's address in `/etc/hosts`;
- installs RKE2, `kubectl`, `helm` and helper scripts in `/usr/local/bin`.

The helpers are `cluster-status`, `rancher-logs`, `port-forward-rancher` and
`uninstall-rancher`. They read root's kubeconfig, so run them with `sudo -i`.

## TLS

By default Rancher signs its own certificate, which browsers do not trust. To use Let's Encrypt,
set the following in `config.yml` or with `-e`:

```yaml
rancher_tls_source: letsEncrypt
rancher_letsencrypt_email: you@example.com
rancher_letsencrypt_environment: production   # or staging
```

`rancher_hostname` must resolve publicly to the host, and port 80 must be reachable from the
internet for the HTTP-01 challenge. Switching an existing install re-issues the certificate.
sslip.io names work. Let's Encrypt's validation timed out on nip.io names during testing.

## Configuration

Settings live in [`ansible/group_vars/all/config.yml`](ansible/group_vars/all/config.yml).

| Variable | Default | Purpose |
|---|---|---|
| `rke2_version`, `cert_manager_version`, `rancher_version`, `helm_version`, `helm_diff_version` | pinned | Component versions. |
| `rke2_ingress_controller` | `ingress-nginx` | `ingress-nginx` or `traefik`. |
| `rancher_tls_source` | `rancher` | `rancher` (self-signed) or `letsEncrypt`. |
| `install_docker` | `true` | Docker is needed by the CAPD (Docker) provider. |
| `selinux_mode` | `permissive` | `""` leaves SELinux alone. |
| `fleet_gitrepo_enabled` | `false` | Registers rancher-fleet-clusters in Fleet. |

The upstream ingress-nginx project was retired in March 2026; Traefik is the alternative RKE2
ships. CAPI provider versions are pinned in
[rancher-fleet-clusters](https://github.com/mbologna/rancher-fleet-clusters#version-matrix).

### Version updates

Renovate opens pull requests for every pin marked `# renovate:` in `config.yml`, and for the
collections, providers and GitHub Actions. RKE2 is held below v1.37 because Rancher 2.15
requires Kubernetes earlier than 1.37. Updates to RKE2, cert-manager and Rancher are never merged
automatically.

## Remove everything

On AWS, run `tofu destroy` in `terraform/`. If it fails with `Your query returned no results`,
run it again. Delete `~/.kube/rancher-platform.yaml` afterwards; it points at the old address.

On your own host, `./manage.sh uninstall-rancher` removes Rancher and cert-manager. To remove
RKE2 too, run `/usr/local/bin/rke2-uninstall.sh` on the host.

## Development

```bash
pre-commit install
pre-commit run --all-files
```

The hooks run yamllint, shellcheck, ansible-lint (production profile), actionlint, `tofu fmt`
and tflint. The [Lint workflow](.github/workflows/lint.yml) runs them, plus `tofu validate`, on
pull requests and pushes to `main`.

The [Deploy test workflow](.github/workflows/deploy-test.yml) runs by hand from the Actions tab.
It creates a host for the chosen OS and ingress controller, deploys twice (the second run must
report `changed=0`), checks `/ping`, and always destroys the host. It needs:

- an IAM role that trusts GitHub's OIDC provider for this repository and can manage EC2, VPC
  subnets, Elastic IPs, key pairs and security groups;
- the role's ARN in the repository secret `AWS_ROLE_ARN`.

### Layout

```
ansible/
  manage.sh              install, deploy, reset, status, uninstall-rancher
  main.yml               Python bootstrap and preflight checks, then the roles
  group_vars/all/        config.yml (versions, paths, toggles), secrets.yml.example
  roles/
    system_reset/        opt-in wipe of RKE2, k3s, kind, k3d and Docker state
    base/                firewall, SELinux, Docker, Python virtualenv, sysctl, /etc/hosts
    helm/                Helm and helm-diff
    rke2/                RKE2 server and kubeconfigs
    cert_manager/        cert-manager chart
    rancher/             Rancher chart, TLS, waits for the API and Turtles
    fleet_gitrepo/       optional rancher-fleet-clusters registration
    dev_tools/           helper scripts
terraform/
  modules/vpc/           subnet, route table, optional VPC and internet gateway
  modules/ec2/           instance, key pair, Elastic IP
  modules/security-groups/
  backend.tf.example     S3 remote state
```

Licensed under the [Apache License 2.0](LICENSE).
