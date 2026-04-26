# rancher-platform

> Use Rancher as a **platform** for provisioning and managing Kubernetes clusters through code.

---

## What is this?

This repo gets you a running **Rancher management cluster** — the platform on which cluster
provisioning via [Cluster API (CAPI)](https://cluster-api.sigs.k8s.io/) happens.

It is designed for:

- **Rancher Engineering** — spin up a fully configured Rancher instance in minutes to experiment
  with CAPI providers, reproduce bugs, or test upgrades.
- **Solution Architects** — bootstrap a Rancher demo environment from scratch, or install Rancher
  on any Linux machine for an end-to-end IaC demo.

> **Scope**: this repo installs Rancher and bootstraps the CAPI platform (Turtles).
> CAPI providers, ClusterClasses, and cluster definitions live in
> **[rancher-fleet-clusters](https://github.com/mbologna/rancher-fleet-clusters)** — register
> that repo in Fleet after this one is done.

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

Any machine works — cloud VM, bare metal, or any Linux host where you have root or SSH access.

---

## Step 1 — Get a machine *(skip if you already have one)*

**Option A: any machine you control**

Skip to Step 2 — just make sure you have SSH access and the user can run commands as root.

**Option B: provision one on AWS with Terraform / OpenTofu**

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars: set region, SSH key name, restrict allowed_ssh_cidrs
tofu init && tofu apply   # or: terraform init && terraform apply
```

Provisions: EC2 instance · VPC · Elastic IP · Security Group.
The Ansible inventory is written automatically to `terraform/generated/hosts.yml`.

---

## Step 2 — Install Rancher

Supported OS:

| OS family | Tested on | Notes |
|---|---|---|
| **SUSE** | openSUSE Leap 15.6 | Default via Terraform (official SUSE AMI). SLE 15.x also supported — `python3` module registered via `suseconnect` automatically. |
| **Debian** | Ubuntu 22.04 / 24.04 | Bring your own machine. |

**2a. Point Ansible at your host**

If you used Terraform, the inventory was already written. Otherwise edit
`ansible/inventory/hosts.yml`:

```yaml
servers:
  hosts:
    my-host:
      ansible_host: 1.2.3.4
      ansible_user: root
```

**2b. Configure the Rancher password**

```bash
cd ansible
cp vars/secrets.yml.example vars/secrets.yml
# edit secrets.yml: set rancher_bootstrap_password
```

**2c. Run the playbook**

```bash
./manage.sh install                                         # install Ansible collections (once)
./manage.sh deploy                                          # uses ansible/inventory/hosts.yml
./manage.sh deploy -i ../terraform/generated/hosts.yml      # or use the Terraform inventory
```

When the playbook finishes you get:

- Rancher running at `https://<host>`
- **Kubeconfig fetched to `~/.kube/rancher-platform.yaml`** on your local machine
- `kubectl` working over SSH: `ssh ec2-user@<host>` → `kubectl get nodes`
- Rancher Turtles v0.26 installed and Cluster API bootstrapped (CoreProvider ready)

**Next**: register [rancher-fleet-clusters](https://github.com/mbologna/rancher-fleet-clusters) in Fleet
to deploy CAPI providers, ClusterClasses, and example clusters — see that repo's README for the
one-command registration.

---

## Integration with other SUSE products

### SUSE Multi-Linux Manager (MLM)

If the target machine is already registered as a managed node in
[SUSE Multi-Linux Manager](https://www.suse.com/products/multi-linux-manager/), point Ansible
at it directly — Step 2 is identical. The result is Rancher installed and configured on a
customer-managed machine, ready for a live CAPI demo.

```yaml
# ansible/inventory/hosts.yml
servers:
  hosts:
    mlm-managed-host:
      ansible_host: <mlm-node-ip>
      ansible_user: root
```

---

## Repository layout

```
rancher-platform/
├── ansible/
│   ├── manage.sh                    # deploy / install / destroy / status
│   ├── main.yml                     # top-level playbook
│   ├── inventory/hosts.yml          # target hosts
│   ├── vars/
│   │   ├── config.yml               # version pins and settings
│   │   └── secrets.yml.example      # credential template (never committed)
│   └── roles/
│       ├── system_reset/            # wipe previous RKE2/k3s/Docker state
│       ├── common/                  # Docker, sysctl tuning
│       ├── cluster_tools/           # Helm
│       ├── rke2/                    # RKE2 single-node install + kubeconfig
│       ├── cluster_provisioning/    # cert-manager
│       ├── rancher_manager/         # Rancher Helm chart + API token
│       ├── rancher_turtles/         # ClusterctlConfig for custom provider URLs (Turtles v0.26 bundled in Rancher v2.14+)
│       └── development_tools/       # helper scripts (cluster-status, rancher-logs, …)
└── terraform/
    ├── main.tf
    ├── variables.tf / outputs.tf
    ├── terraform.tfvars.example     # copy → terraform.tfvars (gitignored)
    └── modules/
        ├── vpc/                     # VPC, IGW, public subnet, route table
        ├── ec2/                     # openSUSE Leap 15.6, key pair, Elastic IP
        └── security-groups/         # ports 22/80/443/6443/9345/30000-32767/8472udp
```

---

## Version pins (`ansible/vars/config.yml`)

| Component       | Version        |
|-----------------|----------------|
| RKE2            | v1.34.6+rke2r3 |
| cert-manager    | v1.20.1        |
| Rancher         | v2.14+ (latest channel) — ships Turtles v0.26 + CAPI v1.12.x |
| Turtles         | v0.26 (bundled with Rancher v2.14 — auto-manages CoreProvider) |
| CAPRKE2         | v0.24.2        |
| CAPA (AWS)      | v2.10.2        |
| CAPM3 (Metal3)  | v1.12.3        |
| CAPD (Docker)   | v1.12.5        |

---

## Related

**[rancher-fleet-clusters](https://github.com/mbologna/rancher-fleet-clusters)** — CAPI providers,
ClusterClasses, and example clusters — deployed automatically by Fleet after this repo runs.
