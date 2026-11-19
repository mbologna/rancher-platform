# Reference

## Commands

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

`uninstall-rancher` removes Rancher AI and keeps RKE2 and the downstream clusters; the next `deploy` reinstalls Rancher
and re-imports the kind clusters. Clusters provisioned by Rancher have not been tested across a
reinstall; remove them from `downstream_clusters` and deploy before uninstalling.

## Configuration

Settings and pinned versions live in
[`ansible/group_vars/all/config.yml`](../ansible/group_vars/all/config.yml).

| Variable | Default | Purpose |
|---|---|---|
| `rancher_hostname` | `ansible_host` or `rancher.<ip>.sslip.io` | Name Rancher answers on. Changing it on a running host moves Rancher, the kubeconfig and the downstream agents to the new name. |
| `rancher_tls_source` | `rancher` | `rancher` (self-signed) or `letsEncrypt`; the latter needs `rancher_letsencrypt_email`, public DNS and port 80 open to the internet. |
| `rancher_chart_channel` | `stable` | `stable`, `latest` (release candidates) or `alpha`; pair it with `rancher_version`. See [Upgrades](upgrades.md). |
| `rancher_image_tag` | | Rancher image tag, such as `head` or `v2.15-head`; `rancher_image` replaces `rancher/rancher`. |
| `rancher_extra_values` | `{}` | Chart values merged over the playbook's own. |
| `rancher_settings` | `{}` | Rancher settings by name, such as `ui-dashboard-index`. |
| `rancher_ai_enabled` | `true` | Install the Rancher AI agent/MCP and UI extension; configure the LLM in the UI. See [Rancher AI](rancher-ai.md). |
| `downstream_clusters` | `[]` | kind clusters to create and import, or (`type: rke2`) clusters for Rancher to provision on Docker containers. See [Downstream clusters](downstream-clusters.md). |
| `fleet_apps` | `[]` | Git repositories Fleet deploys to every cluster; `fleet_apps_examples` holds four samples. See [Fleet apps](fleet-apps.md). |
| `helm_charts` | `[]` | Helm charts for the Rancher cluster; presets `helm_charts_monitoring`, `helm_charts_backup`, `helm_charts_kubewarden`, `helm_charts_longhorn`, `helm_charts_harbor`. See [Helm charts](helm-charts.md). |
| `downstream_metrics_server` | `false` | Install metrics-server in each kind cluster. |
| `registry_cache_enabled` | `false` | Cache container images on the host for RKE2 and the kind clusters. See [Registry cache](registry-cache.md). |
| `selinux_mode` | `permissive` | `""` leaves SELinux alone. |
| `install_docker` | `true` | Install Docker on the host. |
| `rke2_etcd_snapshot_schedule` | `0 */12 * * *` | etcd snapshot schedule; `rke2_etcd_snapshot_retention` keeps 5. See [Snapshots](snapshots.md). |
| `rke2_etcd_s3_bucket` | | Also upload snapshots to S3. |
| `capi_providers_enabled` | `false` | Install Cluster API providers for [Rancher Turtles](https://turtles.docs.rancher.com/); AWS keys in `secrets.yml` enable CAPA. See [Cluster API](fleet-apps.md#cluster-api). |

## What deploy changes on the host

It disables firewalld and ufw, sets SELinux to permissive, installs Docker, a Python virtualenv,
RKE2, `kubectl` and `helm`, writes kernel settings and adds `rancher_hostname` to `/etc/hosts`.
With `helm_charts_longhorn` it also installs `open-iscsi` and the NFS client and starts `iscsid`.
Only `reset` removes existing workloads.
