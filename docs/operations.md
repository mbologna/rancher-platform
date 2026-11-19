# Operations

Run every `./manage.sh` command from `ansible/`. Extra arguments go to `ansible-playbook`, for
example `-i inventory/lima.yml` or `-e '{"downstream_clusters": ["dev"]}'`.

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

## Kubeconfig

`deploy` writes `~/.kube/rancher-platform.yaml`, with one context per cluster, all reached through
Rancher on port 443:

```bash
export KUBECONFIG=~/.kube/rancher-platform.yaml
kubectl config get-contexts   # <host>, <host>-dev, <host>-staging
```

`<host>` is the inventory name, so files from several hosts merge without clashes;
`kubeconfig_context_name` changes it. The file holds an `admin` token valid for 30 days.
`./manage.sh kubeconfig` issues a new one and revokes the old. If you change the `admin` password
in the UI, set `rancher_admin_password` in `secrets.yml`; otherwise `deploy` falls back to the RKE2
kubeconfig on port 6443, which reaches only the Rancher cluster. `kubeconfig_via_rancher: false`
always uses that RKE2 kubeconfig.

## Rancher AI

Each host's Rancher gets
[Liz, the Rancher AI Assistant](https://documentation.suse.com/cloudnative/rancher-ai/1.1.0/en/quick-start.html):
the agent and MCP server in `cattle-ai-agent-system`, and the UI extension in
`cattle-ui-plugin-system`. Reload the Rancher UI after installation, then configure a provider and
model under **Global Settings → AI Assistant**. No Ollama server, model or provider credentials
are installed. Later deploys keep the provider settings and credentials saved through the UI.

AI 1.1.0's agent chart declares Rancher 2.13 and Kubernetes <1.35 in its
[catalogue annotations](https://github.com/rancher/rancher-ai-agent/blob/v1.1.0/chart/agent/Chart.yaml),
although the quick start says Rancher 2.13 or above. This project installs it directly with Helm
on the pinned Rancher 2.15 and Kubernetes 1.36. Agent and MCP readiness and UI extension loading
were verified on that platform; LLM requests have not been tested. The
[UI extension](https://github.com/rancher/ui-plugin-charts/blob/main/charts/rancher-ai-ui/1.1.0/Chart.yaml)
is marked Prime-only. `rancher_ai_enabled: false` stops `deploy` managing AI and leaves an
existing installation in place.

## Upgrades

Renovate proposes version bumps. Patch releases of RKE2, cert-manager and Rancher merge once the
E2E workflow has deployed them; minor and major ones wait for review. Pull and run
`./manage.sh deploy`.

`deploy` refuses to skip or roll back a Kubernetes minor: go from 1.34 to 1.36 via
`-e rke2_version=<a v1.35.x release>`. Before Rancher changes version or image, it saves an etcd
snapshot named `pre-upgrade-<from>-to-<to>`. Rancher cannot be downgraded, so `deploy` refuses an
older `rancher_version`; restore that snapshot instead.

Changing `rancher_hostname` on a running host moves Rancher, the kubeconfig and the downstream
agents to the new name.

## Development builds

Release candidates and alphas come from other chart channels; nightly builds are image tags on the
pinned chart:

```bash
./manage.sh deploy -e rancher_chart_channel=latest -e rancher_version=2.15.2-rc1
./manage.sh deploy -e rancher_image_tag=v2.15-head   # or head for the next minor
```

Each deploy with a `head` tag compares the image digest on Docker Hub with the running pod and
restarts Rancher when a newer build exists. Images from other registries (`rancher_image`) are
restarted on every deploy. `rancher_settings` sets Rancher settings, for example
`ui-dashboard-index` to load the dashboard from a local UI build, and `rancher_extra_values`
merges chart values over the playbook's own.

## Snapshots and restore

etcd holds all RKE2 and Rancher state. RKE2 snapshots it every 12 hours to
`/var/lib/rancher/rke2/server/db/snapshots` and keeps 5; set `rke2_etcd_s3_bucket` to keep copies
off the host. Take one before an experiment and roll back afterwards:

```bash
./manage.sh snapshot before-test   # save, then list all snapshots
./manage.sh snapshots
./manage.sh restore before-test    # about 3 minutes; Rancher is down meanwhile
```

`restore` takes the newest snapshot whose name starts with the one given. It rolls back Rancher,
Fleet and everything on the Rancher cluster. The kind clusters keep running and reconnect; Fleet
then redeploys the apps it had at snapshot time, but other workloads inside them are not restored.

## Image cache

Repeated resets and new kind clusters pull the same images again, and Docker Hub limits anonymous
pulls. `registry_cache_enabled: true` runs a pull-through cache on the host for docker.io,
ghcr.io, quay.io and registry.k8s.io, on ports 5001-5004. RKE2 and the downstream clusters pull
through it and go to the upstream registry when it is down. The images stay in Docker volumes
`rp-registry-*` when the cache is turned off; `reset` deletes them. Set
`registry_cache_dockerhub_username` and `registry_cache_dockerhub_password` in `secrets.yml` to
pull from Docker Hub as that account; an access token works as the password.

## Tear it down

| Host from | Command |
|---|---|
| AWS | `tofu -chdir=terraform destroy` |
| Lima | `./local/lima.sh down` |
| Your own | `./manage.sh deploy -e '{"downstream_clusters": []}'`, `./manage.sh uninstall-rancher`, then on the host `/usr/local/bin/rke2-uninstall.sh` |

`uninstall-rancher` removes Rancher, Rancher AI and cert-manager, and keeps RKE2 and the
downstream clusters; the next `deploy` reinstalls Rancher and re-imports the kind clusters.
Clusters provisioned by Rancher have not been tested across a reinstall; remove them from
`downstream_clusters` and deploy before uninstalling.

## Troubleshooting

- `./manage.sh status` shows the nodes, the Rancher clusters, the Fleet apps and any pod that is
  not running.
- `deploy` stops at once if the host already runs RKE2 or K3s installed by other means, or another
  service holds port 80, 443, 6443, 9345 or 10250. `./manage.sh reset` wipes the host and deploys.
- `deploy` fails its first check if `rancher_bootstrap_password` is unset, still `CHANGE_ME` or
  shorter than 12 characters, or if `rancher_tls_source: letsEncrypt` has no
  `rancher_letsencrypt_email`. Let's Encrypt also needs public DNS for `rancher_hostname` and port
  80 open to the internet.
- If the kubeconfig only reaches the Rancher cluster on port 6443, the `admin` password changed in
  the UI: set `rancher_admin_password` in `secrets.yml` and run `./manage.sh kubeconfig`.
