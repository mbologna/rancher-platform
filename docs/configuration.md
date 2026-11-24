# Configuration reference

Every setting lives in [`ansible/group_vars/all/config.yml`](../ansible/group_vars/all/config.yml)
and every credential in `ansible/group_vars/all/secrets.yml`, copied from
[`secrets.yml.example`](../ansible/group_vars/all/secrets.yml.example). Override a setting per
host in the inventory, or for one run with `-e`. `<ip>` below is the host's address.

## Rancher

| Variable | Default | Purpose |
|---|---|---|
| `rancher_hostname` | `rancher_host_address` if a DNS name, else `rancher.<ip>.sslip.io` | Name Rancher answers on. Changing it on a running host moves Rancher, the kubeconfig and the downstream agents to the new name. |
| `rancher_host_address` | `ansible_host`, else the inventory name | Address `rancher_hostname` is derived from. |
| `rancher_tls_source` | `rancher` | `rancher` (self-signed) or `letsEncrypt`; the latter needs `rancher_letsencrypt_email`, public DNS and port 80 open to the internet. |
| `rancher_letsencrypt_email` | `""` | Let's Encrypt account email. |
| `rancher_letsencrypt_environment` | `production` | `production` or `staging` (untrusted certificates, looser rate limits). |
| `rancher_chart_channel` | `stable` | `stable`, `latest` (release candidates) or `alpha`; pair it with `rancher_version`. |
| `rancher_chart_repo` | `https://releases.rancher.com/server-charts/{{ rancher_chart_channel }}` | Chart repository. |
| `rancher_image` | `""` | Image repository that replaces the chart's (`rancher/rancher`, or `rancher/rancher-server` from v2.16), for example your own build. |
| `rancher_image_tag` | `""` | Rancher image tag. Development builds (`head`, `v2.15-head`, `v2.17-<commit>-head`) use the chart from their commit; other tags use the pinned chart. |
| `rancher_extra_values` | `{}` | Chart values merged over the playbook's own. |
| `rancher_settings` | `{}` | Rancher settings by name, such as `ui-dashboard-index`. |
| `rancher_ai_enabled` | `true` | Install the Rancher AI agent, MCP server and UI extension; configure the LLM in the UI. `false` leaves an existing installation alone. |

## RKE2 and etcd snapshots

| Variable | Default | Purpose |
|---|---|---|
| `rke2_etcd_snapshot_schedule` | `0 */12 * * *` | etcd snapshot schedule (cron). |
| `rke2_etcd_snapshot_retention` | `5` | Snapshots to keep. |
| `rke2_etcd_s3_bucket` | `""` | Also upload snapshots to this S3 (or S3-compatible) bucket. Without `rke2_etcd_s3_access_key` and `rke2_etcd_s3_secret_key`, RKE2 uses the host's AWS credentials, such as an EC2 instance profile. |
| `rke2_etcd_s3_region` | `us-east-1` | Bucket region. |
| `rke2_etcd_s3_folder` | `""` | Folder in the bucket. |
| `rke2_etcd_s3_endpoint` | `s3.amazonaws.com` | S3 endpoint. |

## Host

| Variable | Default | Purpose |
|---|---|---|
| `install_docker` | `true` | Install Docker on the host. kind clusters, RKE2 node containers, the image cache and CAPD need Docker. |
| `capd_enabled` | `{{ install_docker }}` | Install the CAPD provider (with `capi_providers_enabled`) and create its Docker network `kind`. Set `true` with `install_docker: false` when the host already runs Docker. |
| `selinux_mode` | `permissive` | SELinux mode to set; `""` leaves SELinux alone. Leap 16 and SLE 16 enforce SELinux, and RKE2's tarball install does not ship the rke2-selinux policy. |
| `reset` | `false` | Wipe RKE2, K3s, kind, k3d and Docker state before deploying. Use `./manage.sh reset`. |

## Image cache

| Variable | Default | Purpose |
|---|---|---|
| `registry_cache_enabled` | `false` | Run a pull-through cache on the host for RKE2 and the downstream clusters. |
| `registry_cache_upstreams` | docker.io, ghcr.io, quay.io and registry.k8s.io on ports 5001-5004 | Registries to cache, as `{registry, url, port}`. |
| `registry_cache_address` | the host's default IPv4 address | Address the caches listen on; RKE2 and the kind nodes must reach it. |
| `registry_cache_mirrors` | derived | Registry name to mirror URL, empty when the cache is off. |

## Downstream clusters

| Variable | Default | Purpose |
|---|---|---|
| `downstream_clusters` | `[]` | kind clusters to create and import, as names or `{name, kubernetes_version, labels}`, or `{name, type: rke2, kubernetes_version, nodes, labels}` for clusters Rancher provisions on Docker containers. See [downstream-clusters.md](downstream-clusters.md). |
| `downstream_metrics_server` | `false` | Install metrics-server in each kind cluster. |

## Fleet apps and Helm charts

| Variable | Default | Purpose |
|---|---|---|
| `fleet_apps` | `[]` | Git repositories Fleet deploys, as `{name, repo, paths}` with optional `branch`, `workspaces`, `targets`, `keep_resources` and `ingress`. |
| `fleet_apps_examples` | four apps | Samples: `podinfo`, `guestbook`, `guestbook-helm`, `guestbook-multi`. |
| `fleet_apps_capi_templates` | GitRepo `capi-cluster-templates` | The `fleet/` ClusterClasses, identity and example clusters, from `https://github.com/mbologna/rancher-platform` branch `main`, in `fleet-local` with `keep_resources: true`. Needs `capi_providers_enabled`. |
| `fleet_apps_ingress_domain` | the sslip.io domain of `rancher_hostname`, else `<ip>.sslip.io` | Wildcard DNS domain for app Ingresses. |
| `helm_charts` | `[]` | Helm charts for the Rancher cluster, as `{name, repo, namespace}` with optional `chart`, `version`, `values` and `reuse_secret_values`. |
| `helm_charts_monitoring`, `helm_charts_backup`, `helm_charts_kubewarden`, `helm_charts_longhorn`, `helm_charts_harbor` | presets | Chart lists for `helm_charts`; combine them with `+`. |

## Cluster API

| Variable | Default | Purpose |
|---|---|---|
| `capi_providers_enabled` | `false` | Install CAPRKE2, CAPD and, when the AWS keys are set, CAPA with the `rancher-turtles-providers` chart. |
| `capi_providers_values_file` | `{{ playbook_dir }}/../fleet/platform/providers-values.yaml` | Provider values copied from the checkout. |
| `capi_providers_values_url` | `""` | URL of another values file to download instead. |
| `capa_aws_region` | `eu-west-1` | Region written to CAPA's credentials profile. |

## Kubeconfig and paths

| Variable | Default | Purpose |
|---|---|---|
| `local_kubeconfig` | `~/.kube/rancher-platform.yaml` | Kubeconfig written on your machine. |
| `kubeconfig_via_rancher` | `true` | Reach the clusters through Rancher on port 443 with a 30-day token; `false` fetches the RKE2 admin kubeconfig (port 6443, Rancher cluster only). |
| `kubeconfig_refresh` | `false` | Write a new local kubeconfig and token even if the current one is valid; `./manage.sh kubeconfig` sets it. |
| `kubeconfig_context_name` | `{{ inventory_hostname }}` | Context, cluster and user name of the Rancher host; downstream clusters get `<name>-<cluster>`. |
| `rancher_dev_dir` | `/root/.rancher-dev` | Working directory on the host. |
| `rke2_kubeconfig` | `/etc/rancher/rke2/rke2.yaml` | RKE2 admin kubeconfig on the host. |
| `rke2_kubeconfig_external` | `{{ rancher_dev_dir }}/rke2-kubeconfig-external.yaml` | RKE2 kubeconfig with the server set to `https://<rancher_hostname>:6443`. |
| `rke2_snapshot_dir` | `/var/lib/rancher/rke2/server/db/snapshots` | Where RKE2 writes etcd snapshots. |
| `rke2_install_prefix` | `/usr/local` | RKE2 install prefix, pinned because get.rke2.io falls back to `/opt/rke2` when `/usr/local` is a mount point (Leap 16 btrfs). |
| `rke2_bin` | `{{ rke2_install_prefix }}/bin/rke2` | RKE2 binary. |
| `bin_dir` | `/usr/local/bin` | Directory for `kubectl` and `helm`. |
| `kubectl_bin`, `helm_bin` | `{{ bin_dir }}/kubectl`, `{{ bin_dir }}/helm` | Binaries. |
| `k8s_venv` | `/opt/rancher-platform/venv` | Python virtualenv for the Kubernetes modules. |
| `k8s_python` | `{{ k8s_venv }}/bin/python` | Its interpreter. |

## Version pins

Renovate keeps these current; the values are in `config.yml`.

| Variable | Pins |
|---|---|
| `rke2_version` | RKE2 on the host, and the default of rke2 downstream clusters |
| `cert_manager_version` | cert-manager |
| `rancher_version` | Rancher chart |
| `rancher_ai_agent_version`, `rancher_ai_ui_version` | Rancher AI agent chart and UI extension |
| `helm_version`, `helm_diff_version` | Helm 4 and the helm-diff plugin |
| `k8s_python_kubernetes_version`, `k8s_python_pyyaml_version` | Python packages of the virtualenv the Kubernetes modules run in |
| `registry_cache_image_version` | `registry` image of the image cache |
| `kind_version`, `kind_node_version` | kind and its default node image |
| `rke2_node_image_version` | `rancher/systemd-node`, the node image of rke2 downstream clusters |
| `metrics_server_version` | metrics-server chart |
| `rancher_monitoring_version`, `rancher_backup_version` | Rancher Monitoring and Backups charts |
| `kubewarden_crds_version`, `kubewarden_controller_version`, `kubewarden_defaults_version` | Kubewarden charts |
| `longhorn_version` | Longhorn chart |
| `harbor_version` | Harbor chart |

The CAPI provider versions are pinned in [`fleet/platform/`](../fleet/platform/), described in
[fleet/README.md](../fleet/README.md#versions).

## Secrets

Set these in `secrets.yml`. Encrypt the file with `ansible-vault` if it holds cloud keys.

| Variable | Purpose |
|---|---|
| `rancher_bootstrap_password` | Rancher `admin` password, 12 or more characters. Required. |
| `rancher_admin_password` | The `admin` password, if you changed it in the UI; `deploy` uses it for the kubeconfig. Defaults to `rancher_bootstrap_password`. |
| `capa_aws_access_key_id`, `capa_aws_secret_access_key` | AWS keys for CAPA, stored as the `capa-credentials` and `cluster-identity` Secrets; setting them enables the AWS provider. |
| `registry_cache_dockerhub_username`, `registry_cache_dockerhub_password` | Docker Hub account for the image cache; an access token works as the password. |
| `rke2_etcd_s3_access_key`, `rke2_etcd_s3_secret_key` | S3 keys for etcd snapshot uploads. |
| `harbor_admin_password` | Harbor `admin` password for `helm_charts_harbor`. Defaults to `rancher_bootstrap_password`. |
