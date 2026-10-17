# rancher-platform

> Use Rancher as a **platform** for provisioning and managing Kubernetes clusters through code.

This repo installs a single-node **Rancher management cluster** (RKE2 + cert-manager + Rancher),
the platform on which [Cluster API (CAPI)](https://cluster-api.sigs.k8s.io/) provisions
downstream clusters through Rancher Turtles.

It is for:

- **Rancher Engineering**: a configured Rancher instance in minutes, to try CAPI providers,
  reproduce bugs or test upgrades.
- **Solution Architects**: a Rancher demo environment from scratch, or Rancher on any Linux
  machine for an end-to-end IaC demo.

> **Scope**: this repo installs Rancher, which bundles Turtles. CAPI providers, ClusterClasses
> and cluster definitions live in
> **[rancher-fleet-clusters](https://github.com/mbologna/rancher-fleet-clusters)**.

---

## Getting started

```
Do you have a machine to install Rancher on?
│
├─ NO ──► Step 1: get a machine
│         Step 2: install Rancher with Ansible
│
└─ YES ──► Step 2: install Rancher with Ansible
```

Any Linux host works (cloud VM or bare metal) if you can SSH in as root or as a sudoer.

---

## Step 1: Get a machine *(skip if you already have one)*

**Option A: any machine you control.** Skip to Step 2.

**Option B: an EC2 instance on AWS, with OpenTofu or Terraform**

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars: region, SSH key, and the required allowed_*_cidrs
tofu init && tofu apply   # or: terraform init && terraform apply
```

This creates a VPC (or reuses one via `existing_vpc_id`), a security group, an openSUSE Leap 16.0
instance and an Elastic IP. `allowed_ssh_cidrs` and `allowed_admin_cidrs` are required and reject
`0.0.0.0/0`. Rancher gets the hostname `rancher.<elastic-ip>.nip.io` unless you set
`rancher_hostname`.

The Ansible inventory is written to `terraform/generated/hosts.yml`. `manage.sh` uses it
automatically when `ansible/inventory/hosts.yml` does not exist.

---

## Step 2: Install Rancher

| OS | Tested on | Notes |
|---|---|---|
| openSUSE Leap 16.0 | Terraform default | SELinux is set to permissive (see `selinux_mode`). |
| SLES / openSUSE Leap 15.x | | Python 3.11 is installed automatically; on SLES the Python 3 module is enabled with `suseconnect`. |
| Ubuntu 22.04 / 24.04 | | Bring your own machine. |

**2a. Point Ansible at your host** *(skip if you used Terraform)*

```bash
cp ansible/inventory/hosts.yml.example ansible/inventory/hosts.yml
# edit hosts.yml: ansible_host, ansible_user and rancher_hostname
```

**2b. Set the Rancher admin password** (12 characters or more)

```bash
cd ansible
cp group_vars/all/secrets.yml.example group_vars/all/secrets.yml
# edit secrets.yml; optionally: ansible-vault encrypt group_vars/all/secrets.yml
```

Both `hosts.yml` and `secrets.yml` are gitignored.

**2c. Run the playbook**

```bash
./manage.sh install   # install the pinned Ansible collections (once)
./manage.sh deploy    # install or update everything; safe to re-run
```

| Command | Effect |
|---|---|
| `install` | Installs the collections in `requirements.yml`. |
| `deploy` | Installs or upgrades RKE2, Helm, cert-manager and Rancher to the pinned versions. Idempotent. |
| `reset` | **Destructive.** Removes RKE2, k3s, kind and k3d, prunes all Docker data, then deploys from scratch. |
| `status` | Runs `cluster-status` on every host. |
| `uninstall-rancher` | Removes Rancher and cert-manager; RKE2 stays. |

Extra arguments go to Ansible, e.g. `./manage.sh deploy -i other.yml -e fleet_gitrepo_enabled=true`.

When the playbook finishes:

- Rancher answers at `https://<rancher_hostname>` (user `admin`).
- The kubeconfig is fetched to `~/.kube/rancher-platform.yaml` on your machine.
- `kubectl` works for the SSH user on the host.
- Turtles (bundled with Rancher v2.14) is running and manages the CAPI core provider.

**Next**: register [rancher-fleet-clusters](https://github.com/mbologna/rancher-fleet-clusters) in
Fleet to install CAPI providers, ClusterClasses and example clusters. Either follow that repo's
README or let the playbook apply its `gitrepo.yaml`:

```bash
./manage.sh deploy -e fleet_gitrepo_enabled=true
```

---

## Configuration

Settings live in [`ansible/group_vars/all/config.yml`](ansible/group_vars/all/config.yml):

| Variable | Default | Purpose |
|---|---|---|
| `rke2_version`, `cert_manager_version`, `rancher_version`, `helm_version`, `helm_diff_version` | pinned | Component versions; Renovate updates them. |
| `rke2_ingress_controller` | `ingress-nginx` | `ingress-nginx` or `traefik`. |
| `install_docker` | `true` | Docker on the host, needed by the CAPD (Docker) provider. |
| `selinux_mode` | `permissive` | Applied when SELinux is enabled; `""` leaves it alone. |
| `fleet_gitrepo_enabled` | `false` | Register rancher-fleet-clusters in Fleet. |
| `reset` | `false` | Set by `./manage.sh reset`. |

CAPI provider versions (CAPRKE2, CAPA, CAPD, CAPM3) are pinned in
[rancher-fleet-clusters](https://github.com/mbologna/rancher-fleet-clusters#version-matrix).

---

## Integration with other SUSE products

### SUSE Multi-Linux Manager (MLM)

A node managed by [SUSE Multi-Linux Manager](https://www.suse.com/products/multi-linux-manager/)
needs no extra setup: add it to the inventory and run Step 2. `deploy` does not wipe existing
workloads; only `reset` does.

```yaml
# ansible/inventory/hosts.yml
servers:
  hosts:
    mlm-managed-host:
      ansible_host: <mlm-node-ip>
      ansible_user: root
      rancher_hostname: rancher.<mlm-node-ip>.nip.io
```

---

## Repository layout

```
rancher-platform/
├── ansible/
│   ├── manage.sh                  # install / deploy / reset / status / uninstall-rancher
│   ├── main.yml                   # playbook: Python bootstrap + preflight, then roles
│   ├── requirements.yml           # pinned collections
│   ├── inventory/hosts.yml.example
│   ├── group_vars/all/
│   │   ├── config.yml             # versions, paths, toggles
│   │   └── secrets.yml.example
│   ├── tasks/summary.yml
│   └── roles/
│       ├── system_reset/          # opt-in wipe of RKE2/k3s/kind/k3d/Docker state
│       ├── base/                  # firewall, SELinux, Docker, Python venv, sysctl, /etc/hosts
│       ├── helm/                  # Helm + helm-diff
│       ├── rke2/                  # RKE2 server + kubeconfigs
│       ├── cert_manager/
│       ├── rancher/               # Rancher chart, waits for the API and Turtles
│       ├── fleet_gitrepo/         # optional rancher-fleet-clusters registration
│       └── dev_tools/             # cluster-status, rancher-logs, port-forward-rancher, uninstall-rancher
└── terraform/
    ├── main.tf / versions.tf / variables.tf / outputs.tf
    ├── terraform.tfvars.example
    ├── templates/hosts.yml.tftpl
    └── modules/
        ├── vpc/                   # VPC, IGW, public subnet, route table
        ├── ec2/                   # Leap 16.0 instance, key pair, Elastic IP
        └── security-groups/       # 22, 80, 443, 6443, 9345, 30000-32767, 8472/udp
```

---

## Development

```bash
pre-commit install
pre-commit run --all-files
```

The hooks run yamllint, shellcheck, ansible-lint (production profile), `tofu fmt` and tflint.
The [Lint workflow](.github/workflows/lint.yml) runs the same hooks plus `tofu validate`.

---

## Related

**[rancher-fleet-clusters](https://github.com/mbologna/rancher-fleet-clusters)**: CAPI providers,
ClusterClasses and example clusters, deployed by Fleet.

Licensed under the [Apache License 2.0](LICENSE).
