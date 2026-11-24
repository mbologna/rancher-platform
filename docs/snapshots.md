# Snapshots and restore

etcd holds all RKE2 and Rancher state. RKE2 snapshots it every 12 hours to
`/var/lib/rancher/rke2/server/db/snapshots` and keeps 5; set `rke2_etcd_s3_bucket` to keep copies
off the host. Take one before an experiment and roll back afterwards (from `ansible/`):

```bash
./manage.sh snapshot before-test   # save, then list all snapshots
./manage.sh snapshots
./manage.sh restore before-test    # about 3 minutes; Rancher is down meanwhile
```

`restore` takes the newest snapshot on the host whose name starts with the one given, or, when
there is none and `rke2_etcd_s3_bucket` is set, the newest such snapshot in the bucket. It rolls
back Rancher, Fleet and everything on the Rancher cluster. The kind clusters keep running and
reconnect; Fleet then redeploys the apps it had at snapshot time, but other workloads inside
them are not restored.

## Restore on a rebuilt host

The S3 copies outlive the host. RKE2 restores a snapshot only with the token of the cluster that
took it, so save it in `secrets.yml` while the host is alive:

```bash
ssh <host> sudo cat /var/lib/rancher/rke2/server/token   # into secrets.yml as rke2_token
```

Setting it on a running cluster changes nothing, as long as it is that value. To rebuild, deploy
the new host with the same `rke2_token` and S3 settings, then restore:

```bash
./manage.sh deploy
./manage.sh restore <name>   # found in the bucket, as the new host has no snapshots of its own
```

Tested on 24 November 2026 with a SeaweedFS S3 endpoint: after `rke2-uninstall.sh`, a fresh deploy
and a restore from the bucket brought back a ConfigMap created before the snapshot.

**Settings:** [RKE2 and etcd snapshots](configuration.md#rke2-and-etcd-snapshots).
