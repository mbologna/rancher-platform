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

The remaining `./manage.sh` commands also run from `ansible/`.

`deploy` installs RKE2, cert-manager, Rancher and Rancher AI. Open `https://<rancher_hostname>` and log in as
`admin`. To encrypt the password file, run `ansible-vault encrypt group_vars/all/secrets.yml`;
`manage.sh` then asks for the vault password.

`deploy` stops before changing anything if the host already runs RKE2 or K3s installed by other
means, or if another service holds port 80, 443, 6443, 9345 or 10250. `./manage.sh reset` wipes
such a host and deploys.

### Rancher AI

Each host's Rancher management cluster gets [Liz, the Rancher AI Assistant](https://documentation.suse.com/cloudnative/rancher-ai/1.1.0/en/quick-start.html):
the agent and MCP in `cattle-ai-agent-system`, and the UI extension in `cattle-ui-plugin-system`.
Reload the Rancher UI after installation, then configure a provider and model under
**Global Settings → AI Assistant**. No Ollama server, model or provider credentials are installed.
Later deploys preserve provider settings and credentials saved through the UI.

AI 1.1.0's agent chart declares Rancher 2.13 and Kubernetes <1.35 in its
[catalogue annotations](https://github.com/rancher/rancher-ai-agent/blob/v1.1.0/chart/agent/Chart.yaml),
although the quick start says Rancher 2.13 or above. This project installs it directly with Helm on
the pinned Rancher 2.15/Kubernetes 1.36 platform. Agent/MCP readiness and UI extension loading were
verified on that platform; LLM requests have not been tested.
The [UI extension](https://github.com/rancher/ui-plugin-charts/blob/main/charts/rancher-ai-ui/1.1.0/Chart.yaml)
is marked Prime-only. Set `rancher_ai_enabled: false` to skip managing AI; this leaves an existing
installation in place.

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

### Clusters provisioned by Rancher

An entry with `type: rke2` is an RKE2 cluster that Rancher itself provisions, as it would on
your own machines (a custom cluster). Its nodes are Docker containers `rp-<name>-<n>` on the
same host, using the [`rancher/systemd-node`](https://hub.docker.com/r/rancher/systemd-node)
image from Rancher's provisioning tests. Use them to try provisioning, upgrades and node changes
from the Rancher UI or API. Rancher does not support this node type, and each node needs about
2 GB of RAM.

```yaml
downstream_clusters:
  - {name: prov, type: rke2}                                         # 1 node, rke2_version
  - {name: prov3, type: rke2, kubernetes_version: v1.35.9+rke2r1, nodes: 3}
```

The first node runs etcd, the control plane and workloads; the others are workers. The version
must be one Rancher offers (`https://<rancher_hostname>/v1-rke2-release/releases`). Raising
`kubernetes_version` upgrades the cluster, and `deploy` waits until every node runs it. Changing
`nodes` adds or removes workers. A new 3-node cluster was ready about 5 minutes after registration on
19 October 2026. The node containers restart with Docker and rejoin by themselves. `deploy`
refuses to turn a kind cluster into an rke2 one, or back; remove the entry first.

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
`master`), `workspaces`, `targets`, `keep_resources` and `ingress`. This one goes only to clusters labelled
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
provide. Labels dropped from an entry are removed from the cluster on the next deploy.

An entry with `ingress: {service, port, namespace}` also gets an Ingress on the Rancher cluster
at `http://<name>.<ip>.sslip.io`; `fleet_apps_ingress_domain` changes the domain. `podinfo` and
`guestbook` have one. For each downstream cluster, the deploy summary prints the same Service
through Rancher's proxy, which works once you are logged in to the UI:

```text
App podinfo:  http://podinfo.10.0.0.5.sslip.io
  on dev:  https://<rancher>/k8s/clusters/c-m-xxxx/api/v1/namespaces/default/services/http:podinfo-charts-podinfo:9898/proxy/
```

`kubectl port-forward` reaches the other apps, for example `kubectl port-forward svc/frontend
8080:80 -n fleet-helm-example`.

### Add Helm charts to the Rancher cluster

`helm_charts` installs charts on the Rancher cluster, in list order. Each entry is
`{name, repo, namespace}`, with optional `chart` (default `name`), `version` and `values`.
Removing an entry uninstalls the release on the next deploy; releases installed by other means
are left alone. Two presets pin Rancher's own charts:

```yaml
helm_charts: "{{ helm_charts_monitoring + helm_charts_backup }}"
downstream_metrics_server: true
```

`helm_charts_monitoring` is Rancher Monitoring (Prometheus, Grafana and Alertmanager, about 2 GB
of RAM), shown under *Monitoring* in the Rancher UI. `helm_charts_backup` is the Rancher Backups
operator; it needs an S3 bucket or a storage location in each `Backup` resource before it can save
anything. `downstream_metrics_server` installs metrics-server in every kind cluster, which
`kubectl top` and HorizontalPodAutoscalers need.

Three more presets cover common add-ons:

- `helm_charts_kubewarden`: the Kubewarden policy engine with its default PolicyServer. It uses
  the cert-manager that is already installed.
- `helm_charts_longhorn`: Longhorn block storage, one replica per volume. Its StorageClass
  `longhorn` is not the default. The deploy installs `open-iscsi` and the NFS client on the host
  and starts `iscsid`.
- `helm_charts_harbor`: a Harbor registry at `http://harbor.<ip>.sslip.io`, for testing private
  registries. Log in as `admin` with `harbor_admin_password` from `secrets.yml`, which defaults to
  `rancher_bootstrap_password`. Data lives in `emptyDir` volumes and is lost when a pod restarts.
  Harbor needs about 2 GB of RAM.

An entry can set `reuse_secret_values: [{secret, key, value}]` for a chart that generates keys or
passwords on every render. The deploy reads the value from that Secret and passes it back at the
dotted `value` path, so a rerun leaves the release unchanged. The Harbor preset uses it.

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
`-e rke2_version=<a v1.35.x release>`. Before Rancher changes version or image, deploy saves an
etcd snapshot named `pre-upgrade-<from>-to-<to>`. Rancher cannot be downgraded, so deploy refuses
an older `rancher_version`; restore that snapshot instead.

**Try a development build.** Release candidates and alphas come from other chart channels; nightly
builds are image tags on the pinned chart:

```bash
./manage.sh deploy -e rancher_chart_channel=latest -e rancher_version=2.15.2-rc1
./manage.sh deploy -e rancher_image_tag=v2.15-head   # or head for the next minor
```

Each deploy with a `head` tag compares the image digest on Docker Hub with the running pod and
restarts Rancher when a newer build exists. Images from other registries (`rancher_image`) are
restarted on every deploy. `rancher_settings` sets Rancher settings, for example
`ui-dashboard-index` to load the dashboard from a local UI build.

**Snapshot and restore.** etcd holds all RKE2 and Rancher state. RKE2 snapshots it every 12
hours to `/var/lib/rancher/rke2/server/db/snapshots`; set `rke2_etcd_s3_bucket` to keep copies off
the host. Take one before an experiment and roll back afterwards:

```bash
./manage.sh snapshot before-test   # save, then list all snapshots
./manage.sh snapshots
./manage.sh restore before-test    # about 3 minutes; Rancher is down meanwhile
```

`restore` takes the newest snapshot whose name starts with the one given. It rolls back Rancher,
Fleet and everything on the Rancher cluster. The kind clusters keep running and reconnect; Fleet
then redeploys the apps it had at snapshot time, but other workloads inside them are not
restored.

**Cache images.** Repeated resets and new kind clusters pull the same images again, and Docker
Hub limits anonymous pulls. `registry_cache_enabled: true` runs a pull-through cache on the host
for docker.io, ghcr.io, quay.io and registry.k8s.io, on ports 5001–5004. RKE2 and the downstream
clusters pull through it and go to the upstream registry when it is down. The images stay in Docker volumes
`rp-registry-*` when the cache is turned off; `reset` deletes them. Set
`registry_cache_dockerhub_username` and `registry_cache_dockerhub_password` in `secrets.yml` to
pull from Docker Hub as that account.

**Check.** `./manage.sh status` shows the nodes, the Rancher clusters, the Fleet apps and any
pod that is not running.

## 6. Tear it down

| Host from | Command |
|---|---|
| AWS | `tofu -chdir=terraform destroy` |
| Lima | `./local/lima.sh down` |
| Your own | `./manage.sh deploy -e '{"downstream_clusters": []}'`, `./manage.sh uninstall-rancher`, then on the host `/usr/local/bin/rke2-uninstall.sh` |

`uninstall-rancher` removes Rancher AI and keeps RKE2 and the downstream clusters; the next `deploy` reinstalls Rancher
and re-imports the kind clusters. Clusters provisioned by Rancher have not been tested across a
reinstall; remove them from `downstream_clusters` and deploy before uninstalling.

## Reference

### Commands

Run from `ansible/`. Extra arguments go to `ansible-playbook`.

| Command | Effect |
|---|---|
| `./manage.sh install` | Install the pinned Ansible collections. |
| `./manage.sh deploy` | Install or upgrade everything to the pinned versions. |
| `./manage.sh status` | Show nodes, Rancher clusters, Fleet apps and pods that are not running. |
| `./manage.sh kubeconfig` | Write a new kubeconfig and revoke the old one. |
| `./manage.sh snapshot [name]` | Save an etcd snapshot (default name `manual`). |
| `./manage.sh snapshots` | List etcd snapshots. |
| `./manage.sh restore <name>` | Restore RKE2 and Rancher from a snapshot. |
| `./manage.sh uninstall-rancher` | Remove Rancher, Rancher AI and cert-manager. |
| `./manage.sh reset` | **Delete all cluster and Docker data** on the host, including RKE2, K3s, kind and k3d installed by anything, then deploy. |

### Configuration

Settings and pinned versions live in
[`ansible/group_vars/all/config.yml`](ansible/group_vars/all/config.yml).

| Variable | Default | Purpose |
|---|---|---|
| `rancher_hostname` | `ansible_host` or `rancher.<ip>.sslip.io` | Name Rancher answers on. Changing it on a running host moves Rancher, the kubeconfig and the downstream agents to the new name. |
| `rancher_tls_source` | `rancher` | `rancher` (self-signed) or `letsEncrypt`; the latter needs `rancher_letsencrypt_email`, public DNS and port 80 open to the internet. |
| `rancher_chart_channel` | `stable` | `stable`, `latest` (release candidates) or `alpha`; pair it with `rancher_version`. |
| `rancher_image_tag` | | Rancher image tag, such as `head` or `v2.15-head`; `rancher_image` replaces `rancher/rancher`. |
| `rancher_extra_values` | `{}` | Chart values merged over the playbook's own. |
| `rancher_settings` | `{}` | Rancher settings by name, such as `ui-dashboard-index`. |
| `rancher_ai_enabled` | `true` | Install the Rancher AI agent/MCP and UI extension; configure the LLM in the UI. |
| `downstream_clusters` | `[]` | kind clusters to create and import, or (`type: rke2`) clusters for Rancher to provision on Docker containers. |
| `fleet_apps` | `[]` | Git repositories Fleet deploys to every cluster; `fleet_apps_examples` holds four samples. |
| `helm_charts` | `[]` | Helm charts for the Rancher cluster; presets `helm_charts_monitoring`, `helm_charts_backup`, `helm_charts_kubewarden`, `helm_charts_longhorn`, `helm_charts_harbor`. |
| `downstream_metrics_server` | `false` | Install metrics-server in each kind cluster. |
| `registry_cache_enabled` | `false` | Cache container images on the host for RKE2 and the kind clusters. |
| `selinux_mode` | `permissive` | `""` leaves SELinux alone. |
| `install_docker` | `true` | Install Docker on the host. |
| `rke2_etcd_snapshot_schedule` | `0 */12 * * *` | etcd snapshot schedule; `rke2_etcd_snapshot_retention` keeps 5. |
| `rke2_etcd_s3_bucket` | | Also upload snapshots to S3. |
| `capi_providers_enabled` | `false` | Install Cluster API providers for [Rancher Turtles](https://turtles.docs.rancher.com/); AWS keys in `secrets.yml` enable CAPA. |

### What deploy changes on the host

It disables firewalld and ufw, sets SELinux to permissive, installs Docker, a Python virtualenv,
RKE2, `kubectl` and `helm`, writes kernel settings and adds `rancher_hostname` to `/etc/hosts`.
With `helm_charts_longhorn` it also installs `open-iscsi` and the NFS client and starts `iscsid`.
Only `reset` removes existing workloads.

## Development

```bash
pre-commit install && pre-commit run --all-files
```

Every pull request runs the same hooks in the [Lint workflow](.github/workflows/lint.yml), plus
trivy and zizmor in the [Security workflow](.github/workflows/security.yml). Pull requests that
touch `ansible/` also run the [E2E workflow](.github/workflows/e2e.yml): it deploys with one
downstream cluster and podinfo as a Fleet app on the GitHub runner, re-runs expecting no changes,
and checks that Rancher answers, the AI agent/MCP and UI extension are installed, AI provider settings
survive the re-run, and podinfo runs on both clusters.
E2E also runs every Monday on
Rancher `head`, pinned to that build's commit tag so both deploys use the same image; run it by
hand with another tag from *Actions → E2E → Run workflow* (`rancher_image_tag`). No workflow uses
cloud resources.

Pull request titles follow [Conventional Commits](https://www.conventionalcommits.org/); the
[Release workflow](.github/workflows/release.yml) tags a version every Monday at 06:00 UTC when a
`feat`, `fix`, `perf`, `revert` or breaking commit landed on `main` (a Renovate `fix(security)` update
is released at once), and publishes its notes on the [Releases page](https://github.com/mbologna/rancher-platform/releases);
run it by hand to release at once. The Releases page holds every version's notes.

Licensed under the [Apache License 2.0](LICENSE).
