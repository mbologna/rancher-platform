# Fleet apps

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

## Your own apps

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

## Cluster labels

`guestbook-multi` reads the cluster label `env`: `dev` drops the Redis replicas and `test` runs
three frontends. `env: prod` asks for a `LoadBalancer` Service, which kind clusters cannot
provide. Labels dropped from an entry are removed from the cluster on the next deploy.

## Reach the apps

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

## Cluster API

For [Rancher Turtles](https://turtles.docs.rancher.com/), set `capi_providers_enabled: true` and
add `fleet_apps_capi_templates`, the ClusterClasses and example clusters from
[rancher-fleet-clusters](https://github.com/mbologna/rancher-fleet-clusters):
`fleet_apps: "{{ fleet_apps_examples + fleet_apps_capi_templates }}"`. AWS keys in `secrets.yml`
enable the AWS provider (CAPA).

**Variables:** `fleet_apps`, `fleet_apps_ingress_domain`, `capi_providers_enabled` (see
[Configuration](reference.md#configuration)).
