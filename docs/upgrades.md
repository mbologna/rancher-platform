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

Release candidates and alphas come from other chart channels; nightly builds are image tags:

```bash
./manage.sh deploy -e rancher_chart_channel=latest -e rancher_version=2.15.2-rc1
./manage.sh deploy -e rancher_image_tag=v2.15-head   # or head for the next minor
```

A nightly build installs with the chart from its own commit, because the released chart stops
matching once Rancher changes how it is packaged: v2.16 runs `rancher/rancher-server` and loads its
system charts from an assets image. Each deploy pins `head` or `v2.15-head` to the commit tag of
the newest build on Docker Hub, such as `v2.17-<commit>-head`, and upgrades Rancher when that
changed, with a snapshot first. For an image outside Docker Hub (`rancher_image`), set the commit
tag yourself. `deploy` compares a nightly build with releases by minor: v2.15-head replaces 2.15.3,
but 2.15.3 does not replace v2.17-head. `rancher_settings` sets Rancher settings, for example
`ui-dashboard-index` to load the dashboard from a local UI build, and `rancher_extra_values`
merges chart values over the playbook's own.

**Settings:** [Rancher](configuration.md#rancher) and [Version pins](configuration.md#version-pins).
