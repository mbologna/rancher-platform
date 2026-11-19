# Upgrades and development builds

Run `./manage.sh` from `ansible/`.

## Upgrades

Renovate proposes version bumps. Patch releases of RKE2, cert-manager and Rancher merge once the
E2E workflow has deployed them; minor and major ones wait for review. Pull and run
`./manage.sh deploy`.

`deploy` refuses to skip or roll back a Kubernetes minor: go from 1.34 to 1.36 via
`-e rke2_version=<a v1.35.x release>`. Before Rancher changes version or image, it saves an etcd
snapshot named `pre-upgrade-<from>-to-<to>`. Rancher cannot be downgraded, so `deploy` refuses an
older `rancher_version`; [restore](snapshots.md) that snapshot instead.

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

**Settings:** [Rancher](configuration.md#rancher) and [Version pins](configuration.md#version-pins).
