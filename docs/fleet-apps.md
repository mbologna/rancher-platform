# Fleet apps

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

## App URLs

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

**Settings:** [Fleet apps and Helm charts](configuration.md#fleet-apps-and-helm-charts). Clusters get labels for Fleet targets in
[Downstream clusters](downstream-clusters.md#cluster-labels).
