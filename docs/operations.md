# Operations

Run every `./manage.sh` command from `ansible/`. Extra arguments go to `ansible-playbook`, for
example `-i inventory/lima.yml` or `-e '{"downstream_clusters": ["dev"]}'`. Upgrades,
snapshots, development builds and the image cache have their own pages, listed in the
[README](../README.md#features).

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
