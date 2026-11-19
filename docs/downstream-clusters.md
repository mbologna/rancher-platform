# Downstream clusters

`deploy` can create clusters for Rancher to manage on the same host. Set `downstream_clusters` in
[`config.yml`](../ansible/group_vars/all/config.yml) or the inventory to keep the list between
deploys, or pass it with `-e` for one run, from `ansible/`. Cluster API clusters, which Rancher
Turtles provisions on Docker or AWS, are described in [Cluster API](cluster-api.md).

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

**Settings:** [Downstream clusters](configuration.md#downstream-clusters).
