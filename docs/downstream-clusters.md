# Downstream clusters

Give Rancher clusters to manage. Run `./manage.sh` from `ansible/`.

```bash
./manage.sh deploy -e '{"downstream_clusters": ["dev", "staging"]}'
```

Each name becomes a kind cluster `rp-<name>` on the same host, imported into Rancher and ready
when `deploy` finishes. Drop a name and deploy again to delete that cluster; clusters `deploy`
did not create are left alone. Set `downstream_clusters` in
[`config.yml`](../ansible/group_vars/all/config.yml) to keep the list. Each kind cluster needs
about 1 GB of RAM.

Clusters run Kubernetes 1.36 unless an entry picks another version that Rancher supports. The
version applies when the cluster is created:

```yaml
downstream_clusters:
  - dev                                         # v1.36.4
  - {name: legacy, kubernetes_version: v1.34.11}
  - {name: staging, kubernetes_version: v1.35.8}
```

An entry can also set `labels`, which Fleet uses to pick target clusters; see
[Fleet apps](fleet-apps.md). `downstream_metrics_server: true` installs metrics-server in every
kind cluster; see [Helm charts](helm-charts.md).

## Clusters provisioned by Rancher

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

Clusters provisioned by Rancher have not been tested across `./manage.sh uninstall-rancher`;
remove them from `downstream_clusters` and deploy before uninstalling.

**Variables:** `downstream_clusters` (see [Configuration](reference.md#configuration)).
