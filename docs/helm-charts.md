# Helm charts

`helm_charts` installs charts on the Rancher cluster, in list order. Each entry is
`{name, repo, namespace}`, with optional `chart` (default `name`), `version` and `values`.
Removing an entry uninstalls the release on the next deploy; releases installed by other means
are left alone. Two presets pin Rancher's own charts:

```yaml
helm_charts: "{{ helm_charts_monitoring + helm_charts_backup }}"
downstream_metrics_server: true
```

`helm_charts_monitoring` is Rancher Monitoring (Prometheus, Grafana and Alertmanager, about 2 GB
of RAM), shown under *Monitoring* in the Rancher UI. `helm_charts_backup` is the Rancher Backups
operator; it needs an S3 bucket or a storage location in each `Backup` resource before it can save
anything. `downstream_metrics_server` installs metrics-server in every kind cluster, which
`kubectl top` and HorizontalPodAutoscalers need.

## More presets

Three more presets cover common add-ons:

- `helm_charts_kubewarden`: the Kubewarden policy engine with its default PolicyServer. It uses
  the cert-manager that is already installed.
- `helm_charts_longhorn`: Longhorn block storage, one replica per volume. Its StorageClass
  `longhorn` is not the default. The deploy installs `open-iscsi` and the NFS client on the host
  and starts `iscsid`.
- `helm_charts_harbor`: a Harbor registry at `http://harbor.<ip>.sslip.io`, for testing private
  registries. Log in as `admin` with `harbor_admin_password` from `secrets.yml`, which defaults to
  `rancher_bootstrap_password`. Data lives in `emptyDir` volumes and is lost when a pod restarts.
  Harbor needs about 2 GB of RAM.

## Charts that generate secrets

An entry can set `reuse_secret_values: [{secret, key, value}]` for a chart that generates keys or
passwords on every render. The deploy reads the value from that Secret and passes it back at the
dotted `value` path, so a rerun leaves the release unchanged. The Harbor preset uses it.

**Variables:** `helm_charts`, `downstream_metrics_server` (see
[Configuration](reference.md#configuration)).
