# Downstream clusters, Fleet apps and Helm charts

`deploy` can create clusters for Rancher to manage on the same host, deploy apps to them with
Fleet, and install Helm charts on the Rancher cluster. Set the lists in
[`config.yml`](../ansible/group_vars/all/config.yml) or the inventory to keep them between
deploys, or pass them with `-e` for one run. Cluster API clusters, which Rancher Turtles
provisions on Docker or AWS, are described in the [README](../README.md#cluster-api) and
[fleet/README.md](../fleet/README.md).

## kind clusters

```bash
./manage.sh deploy -e '{"downstream_clusters": ["dev", "staging"]}'
```

Each name becomes a kind cluster `rp-<name>` on the host, imported into Rancher and ready when
`deploy` finishes. A name is a lowercase DNS label of up to 30 characters. Drop a name and deploy
again to delete that cluster; clusters that `deploy` did not create are left alone. Each cluster
uses about 1 GB of RAM.

Clusters run Kubernetes v1.36 (`kind_node_version`) unless an entry picks another version that
Rancher supports and the pinned kind release offers. The version applies when the cluster is
created:

```yaml
downstream_clusters:
  - dev                                         # v1.36.4
  - {name: legacy, kubernetes_version: v1.34.11}
  - {name: staging, kubernetes_version: v1.35.8}
```

`downstream_metrics_server: true` installs metrics-server in every kind cluster, which
`kubectl top` and HorizontalPodAutoscalers need.

## Clusters provisioned by Rancher

An entry with `type: rke2` is an RKE2 cluster that Rancher itself provisions, as it would on your
own machines (a custom cluster). Its nodes are Docker containers `rp-<name>-<n>` on the host,
using the [`rancher/systemd-node`](https://hub.docker.com/r/rancher/systemd-node) image from
Rancher's provisioning tests. Use them to try provisioning, upgrades and node changes from the
Rancher UI or API. Rancher does not support this node type, and each node needs about 2 GB of RAM.

```yaml
downstream_clusters:
  - {name: prov, type: rke2}                                         # 1 node, rke2_version
  - {name: prov3, type: rke2, kubernetes_version: v1.35.9+rke2r1, nodes: 3}
```

The first node runs etcd, the control plane and workloads; the others are workers. The version
defaults to `rke2_version` and must be one Rancher offers
(`https://<rancher_hostname>/v1-rke2-release/releases`). Raising `kubernetes_version` upgrades the
cluster, and `deploy` waits until every node runs it. Changing `nodes` adds or removes workers. A
new 3-node cluster was ready about 5 minutes after registration on 19 October 2026. The node
containers restart with Docker and rejoin by themselves. `deploy` refuses to turn a kind cluster
into an rke2 one, or back; remove the entry first.

## Cluster labels

An entry's `labels` go on the Rancher cluster, where Fleet targets can select them. Labels dropped
from an entry are removed from the cluster on the next deploy.

```yaml
downstream_clusters:
  - {name: dev, labels: {env: dev}}
  - {name: staging, labels: {env: test}}
```

## Fleet apps

Fleet, which ships with Rancher, deploys apps from Git repositories to the Rancher cluster and
every imported cluster. `fleet_apps_examples` lists four sample apps:

| App | Source | Namespace |
|---|---|---|
| `podinfo` | [stefanprodan/podinfo](https://github.com/stefanprodan/podinfo) Helm chart | `default` |
| `guestbook` | [rancher/fleet-examples](https://github.com/rancher/fleet-examples) `simple` | `default` |
| `guestbook-helm` | fleet-examples `single-cluster/helm` | `fleet-helm-example` |
| `guestbook-multi` | fleet-examples `multi-cluster/helm` | `fleet-mc-helm-example` |

```yaml
fleet_apps: "{{ fleet_apps_examples }}"
```

`deploy` creates one Fleet GitRepo per app in `fleet-local` (the Rancher cluster) and in
`fleet-default` (the imported clusters, including those created with Cluster API), and waits
until Fleet reports them ready. Removing an entry removes that app from every cluster. Combine
lists with `+`, for example `"{{ fleet_apps_examples + fleet_apps_capi_templates }}"`.

`guestbook-multi` reads the cluster label `env`: `dev` drops the Redis replicas and `test` runs
three frontends. `env: prod` asks for a `LoadBalancer` Service, which kind clusters cannot
provide.

Your own apps take the form `{name, repo, paths}`, with these optional keys:

| Key | Default | Meaning |
|---|---|---|
| `branch` | `master` (Fleet's default) | Branch to read. |
| `workspaces` | `[fleet-local, fleet-default]` | Fleet workspaces that get a GitRepo. |
| `targets` | `[{clusterSelector: {}}]` | Fleet GitRepo targets; the default is every cluster in the workspace. |
| `keep_resources` | `false` | Leave the deployed resources in place when the app is removed. |
| `ingress` | | `{service, port, namespace}`: an Ingress on the Rancher cluster (see below). |

This one goes only to clusters labelled `env: dev`:

```yaml
fleet_apps:
  - name: my-app
    repo: https://github.com/me/my-app
    branch: main
    paths: [deploy]
    workspaces: [fleet-default]
    targets: [{clusterSelector: {matchLabels: {env: dev}}}]
```

### App URLs

An entry with `ingress: {service, port, namespace}` (`namespace` defaults to `default`) also gets
an Ingress on the Rancher cluster at `http://<name>.<ip>.sslip.io`, if the app's workspaces
include `fleet-local`. `fleet_apps_ingress_domain` changes the domain. `podinfo` and `guestbook`
have one. For each downstream cluster, the deploy summary prints the same Service through
Rancher's proxy, which works once you are logged in to the UI:

```text
App podinfo:  http://podinfo.<ip>.sslip.io
  on dev:  https://<rancher>/k8s/clusters/c-m-xxxx/api/v1/namespaces/default/services/http:podinfo-charts-podinfo:9898/proxy/
```

`kubectl port-forward` reaches the other apps, for example
`kubectl port-forward svc/frontend 8080:80 -n fleet-helm-example`.

## Helm charts on the Rancher cluster

`helm_charts` installs charts on the Rancher cluster, in list order. Each entry is
`{name, repo, namespace}`, with optional `chart` (default `name`), `version` and `values`.
Removing an entry uninstalls the release on the next deploy; releases installed by other means
are left alone.

```yaml
helm_charts: "{{ helm_charts_monitoring + helm_charts_backup }}"
```

The presets pin their chart versions in `config.yml`:

- `helm_charts_monitoring`: Rancher Monitoring (Prometheus, Grafana and Alertmanager, about 2 GB
  of RAM), shown under *Monitoring* in the Rancher UI.
- `helm_charts_backup`: the Rancher Backups operator. It needs an S3 bucket or a storage location
  in each `Backup` resource before it can save anything.
- `helm_charts_kubewarden`: the Kubewarden policy engine with its default PolicyServer and no
  policies. It uses the cert-manager that is already installed.
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
