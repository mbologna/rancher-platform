# rancher-platform

[![E2E](https://github.com/mbologna/rancher-platform/actions/workflows/e2e.yml/badge.svg)](https://github.com/mbologna/rancher-platform/actions/workflows/e2e.yml)
[![Lint](https://github.com/mbologna/rancher-platform/actions/workflows/lint.yml/badge.svg)](https://github.com/mbologna/rancher-platform/actions/workflows/lint.yml)
[![Version](https://img.shields.io/github/v/tag/mbologna/rancher-platform?label=version)](https://github.com/mbologna/rancher-platform/tags)

Install [Rancher](https://www.rancher.com/) on one Linux host with Ansible, in about seven
minutes. If you have no host, create one on AWS or on your Mac first. Optionally, give Rancher
some clusters to manage straight away.

The steps below go from a bare host to a Rancher managing its own clusters. Run the commands
from the repository root unless noted; all of them are safe to re-run.

## 1. Get a host

You need a Linux host you can SSH into as root or as a user with passwordless sudo, with:

- openSUSE Leap 16.0, SLES 15 SP7, or Ubuntu 22.04 or 24.04 (tested on 17 October 2026);
- 4 vCPUs, 16 GB RAM and 100 GB disk, plus about 1 GB RAM per downstream cluster;
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

The remaining `./manage.sh` commands also run from `ansible/`.

`deploy` installs RKE2, cert-manager and Rancher. Open `https://<rancher_hostname>` and log in as
`admin`. To encrypt the password file, run `ansible-vault encrypt group_vars/all/secrets.yml`;
`manage.sh` then asks for the vault password.

`deploy` stops before changing anything if the host already runs RKE2 or K3s installed by other
means, or if another service holds port 80, 443, 6443, 9345 or 10250. `./manage.sh reset` wipes
such a host and deploys.

## 3. Give Rancher clusters to manage (optional)

```bash
./manage.sh deploy -e '{"downstream_clusters": ["dev", "staging"]}'
```

Each name becomes a kind cluster `rp-<name>` on the same host, imported into Rancher and ready
when `deploy` finishes. Drop a name and deploy again to delete that cluster; clusters `deploy`
did not create are left alone. Set `downstream_clusters` in
[`config.yml`](ansible/group_vars/all/config.yml) to keep the list.

Clusters run Kubernetes 1.36 unless an entry picks another version that Rancher supports. The
version applies when the cluster is created:

```yaml
downstream_clusters:
  - dev                                         # v1.36.4
  - {name: legacy, kubernetes_version: v1.34.11}
  - {name: staging, kubernetes_version: v1.35.8}
```

### Deploy apps to every cluster

Fleet, which ships with Rancher, can deploy apps from Git repositories to the Rancher cluster and
every imported cluster. `fleet_apps_examples` lists four sample apps:

| App | Source | Namespace |
|---|---|---|
| `podinfo` | [stefanprodan/podinfo](https://github.com/stefanprodan/podinfo) Helm chart | `default` |
| `guestbook` | [rancher/fleet-examples](https://github.com/rancher/fleet-examples) `simple` | `default` |
| `guestbook-helm` | fleet-examples `single-cluster/helm` | `fleet-helm-example` |
| `guestbook-multi` | fleet-examples `multi-cluster/helm` | `fleet-mc-helm-example` |

```yaml
fleet_apps: "{{ fleet_apps_examples }}"
downstream_clusters:
  - {name: dev, labels: {env: dev}}
  - {name: staging, labels: {env: test}}
```

`deploy` creates one Fleet GitRepo per app in `fleet-local` (the Rancher cluster) and in
`fleet-default` (the imported clusters, including any created with Cluster API), and waits until
Fleet reports them ready. Removing an entry removes that app from every cluster.

Your own apps take the same form, `{name, repo, paths}`, with optional `branch` (default
`master`), `workspaces`, `targets` and `keep_resources`. This one goes only to clusters labelled
`env: dev`:

```yaml
fleet_apps:
  - name: my-app
    repo: https://github.com/me/my-app
    branch: main
    paths: [deploy]
    workspaces: [fleet-default]
    targets: [{clusterSelector: {matchLabels: {env: dev}}}]
```

For [Rancher Turtles](https://turtles.docs.rancher.com/), set `capi_providers_enabled: true` and
add `fleet_apps_capi_templates`, the ClusterClasses and example clusters from
[rancher-fleet-clusters](https://github.com/mbologna/rancher-fleet-clusters):
`fleet_apps: "{{ fleet_apps_examples + fleet_apps_capi_templates }}"`.

`guestbook-multi` reads the cluster label `env`: `dev` drops the Redis replicas and `test` runs
three frontends. `env: prod` asks for a `LoadBalancer` Service, which kind clusters cannot
provide. The apps have no ingress; reach them with `kubectl port-forward`, for example
`kubectl port-forward svc/podinfo-charts-podinfo 9898` (podinfo) or
`kubectl port-forward svc/frontend 8080:80` (guestbook).

## 4. Use the clusters

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

## 5. Keep it running

**Upgrade.** Renovate proposes version bumps. Patch releases of RKE2, cert-manager and Rancher
merge once the E2E workflow has deployed them; minor and major ones wait for review. Pull and run
`./manage.sh deploy`. It refuses to skip a Kubernetes minor: go from 1.34 to 1.36 via
`-e rke2_version=<a v1.35.x release>`.

**Back up.** RKE2 snapshots etcd, which holds all cluster and Rancher state, every 12 hours to
`/var/lib/rancher/rke2/server/db/snapshots`. Set `rke2_etcd_s3_bucket` to keep copies off the
host. Restore with the [RKE2 procedure](https://docs.rke2.io/datastore/backup_restore).

**Check.** `./manage.sh status` shows the nodes, the Rancher clusters, the Fleet apps and any
pod that is not running.

## 6. Tear it down

| Host from | Command |
|---|---|
| AWS | `tofu -chdir=terraform destroy` |
| Lima | `./local/lima.sh down` |
| Your own | `./manage.sh uninstall-rancher`, then on the host `kind delete clusters --all` and `/usr/local/bin/rke2-uninstall.sh` |

`uninstall-rancher` keeps RKE2 and the downstream clusters; the next `deploy` reinstalls Rancher
and re-imports them.

## Reference

### Commands

Run from `ansible/`. Extra arguments go to `ansible-playbook`.

| Command | Effect |
|---|---|
| `./manage.sh install` | Install the pinned Ansible collections. |
| `./manage.sh deploy` | Install or upgrade everything to the pinned versions. |
| `./manage.sh status` | Show nodes, Rancher clusters, Fleet apps and pods that are not running. |
| `./manage.sh kubeconfig` | Write a new kubeconfig and revoke the old one. |
| `./manage.sh uninstall-rancher` | Remove Rancher and cert-manager. |
| `./manage.sh reset` | **Delete all cluster and Docker data** on the host, including RKE2, K3s, kind and k3d installed by anything, then deploy. |

### Configuration

Settings and pinned versions live in
[`ansible/group_vars/all/config.yml`](ansible/group_vars/all/config.yml).

| Variable | Default | Purpose |
|---|---|---|
| `rancher_hostname` | `ansible_host` or `rancher.<ip>.sslip.io` | Name Rancher answers on. Changing it on a running host moves Rancher, the kubeconfig and the downstream agents to the new name. |
| `rancher_tls_source` | `rancher` | `rancher` (self-signed) or `letsEncrypt`; the latter needs `rancher_letsencrypt_email`, public DNS and port 80 open to the internet. |
| `downstream_clusters` | `[]` | kind clusters to create and import. |
| `fleet_apps` | `[]` | Git repositories Fleet deploys to every cluster; `fleet_apps_examples` holds four samples. |
| `rke2_ingress_controller` | `traefik` | `traefik` or `ingress-nginx`. |
| `selinux_mode` | `permissive` | `""` leaves SELinux alone. |
| `install_docker` | `true` | Install Docker on the host. |
| `rke2_etcd_snapshot_schedule` | `0 */12 * * *` | etcd snapshot schedule; `rke2_etcd_snapshot_retention` keeps 5. |
| `rke2_etcd_s3_bucket` | | Also upload snapshots to S3. |
| `capi_providers_enabled` | `false` | Install Cluster API providers for [Rancher Turtles](https://turtles.docs.rancher.com/); AWS keys in `secrets.yml` enable CAPA. |

### What deploy changes on the host

It disables firewalld and ufw, sets SELinux to permissive, installs Docker, a Python virtualenv,
RKE2, `kubectl` and `helm`, writes kernel
settings and adds `rancher_hostname` to `/etc/hosts`. Only `reset` removes existing workloads.

## Development

```bash
pre-commit install && pre-commit run --all-files
```

Every pull request runs the same hooks in the [Lint workflow](.github/workflows/lint.yml), plus
trivy and zizmor in the [Security workflow](.github/workflows/security.yml). Pull requests that
touch `ansible/` also run the [E2E workflow](.github/workflows/e2e.yml): it deploys with one
downstream cluster and podinfo as a Fleet app on the GitHub runner, re-runs expecting no changes,
and checks that Rancher answers and podinfo runs on both clusters. No workflow uses cloud resources.

Pull request titles follow [Conventional Commits](https://www.conventionalcommits.org/); the
[Release workflow](.github/workflows/release.yml) turns them into `CHANGELOG.md` and version tags.

Licensed under the [Apache License 2.0](LICENSE).
