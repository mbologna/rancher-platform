# Hosts

rancher-platform installs everything on one Linux host that you reach over SSH as root or as a
user with passwordless sudo. The host needs:

- openSUSE Leap 16.1 (tested on 24 November 2026), or Leap 16.0, SLES 15 SP7, or Ubuntu 22.04 or
  24.04 (tested on 17 October 2026);
- 4 vCPUs, 16 GB RAM and 100 GB disk, plus about 1 GB RAM per kind cluster and 2 GB per node
  of a cluster that Rancher provisions;
- ports 80 and 443 reachable from your browser.

On SLE and Leap 15, whose Python 3.6 is too old for ansible-core, the playbook installs
`python311` first (on SLES it enables the SLE Python 3 module).

## A host you have

Copy the inventory and set `ansible_host` to the host's address:

```bash
cp ansible/inventory/hosts.yml.example ansible/inventory/hosts.yml
```

Rancher answers on that address if it is a DNS name, or on `rancher.<ip>.sslip.io` if it is an IP
address. Set `rancher_hostname` in the inventory to use another name.

## A new host on AWS

`terraform/` creates a `t3.xlarge` instance (4 vCPUs, 16 GB RAM) running openSUSE Leap 16.1, with
a 100 GB encrypted disk and an Elastic IP, and writes the inventory to
`terraform/generated/hosts.yml`, with Rancher on `rancher.<elastic-ip>.sslip.io`. You need
[OpenTofu](https://opentofu.org/) or Terraform 1.6+ and AWS credentials.

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars   # region, SSH key, source CIDRs
tofu -chdir=terraform init && tofu -chdir=terraform apply
```

Ports 80 and 443 are open to everyone. SSH (22) is open only to `allowed_ssh_cidrs` and the
Kubernetes API (6443) only to `allowed_admin_cidrs`; both reject `0.0.0.0/0`.
`allowed_cluster_cidrs` lists the networks of downstream CAPI cluster nodes, typically their VPC
CIDRs, which get 6443, 9345, 30000-32767 and 8472/udp. `existing_vpc_id` reuses a VPC instead of
creating one, and `ami_name_filter` and `ami_owner` pick another image. To keep the state in S3,
copy `terraform/backend.tf.example` to `terraform/backend.tf`, set the bucket and run
`tofu init -migrate-state`. The state holds the instance's details in plain text; to encrypt it
and the plans with OpenTofu, copy `terraform/encryption.tofu.example` to
`terraform/encryption.tofu` and set `TF_VAR_state_passphrase` before each `tofu` command. The
next apply encrypts the existing state; the file explains how to finish the migration.

## A VM on a Mac

[Lima](https://lima-vm.io/) starts an openSUSE Leap 16.1 VM with 4 vCPUs, 12 GiB RAM and a 60 GiB
disk, on an address the Mac can reach, and writes `ansible/inventory/lima.yml`, which
`manage.sh` uses while there is no `inventory/hosts.yml`:

```bash
./local/lima.sh up
cd ansible && ./manage.sh deploy
```

`LIMA_INSTANCE` changes the VM name (default `rancher-platform`). `./local/lima.sh down` deletes
the VM and its inventory.

## Inventory

`./manage.sh` uses `ansible/inventory/hosts.yml` if it exists, otherwise
`terraform/generated/hosts.yml`; `-i` overrides both. Settings from
[configuration.md](configuration.md) can go on a host in the inventory, which is how one checkout
deploys several hosts with different options.

To encrypt `secrets.yml`, run `ansible-vault encrypt group_vars/all/secrets.yml` from `ansible/`;
`./manage.sh` then asks for the vault password unless `ANSIBLE_VAULT_PASSWORD_FILE` or another
vault option is set.

## What deploy changes on the host

`deploy` disables firewalld and ufw, sets SELinux to permissive (`selinux_mode`), installs Docker
(`install_docker`), a Python virtualenv in `/opt/rancher-platform/venv`, RKE2, `kubectl` and
`helm`, writes kernel settings and adds `rancher_hostname` to `/etc/hosts`. While `capd_enabled`
is true (it follows `install_docker`), it creates a Docker network called `kind` for the CAPI
Docker provider. With `helm_charts_longhorn` it also
installs `open-iscsi` and the NFS client and starts `iscsid`. Only `reset` removes existing
workloads.

`deploy` stops before changing anything if the host already runs RKE2 or K3s installed by other
means, or if another service holds port 80, 443, 6443, 9345 or 10250. `./manage.sh reset` wipes
such a host (RKE2, K3s, kind, k3d and all Docker data, whatever installed them) and then deploys.
