# Snapshots and restore

etcd holds all RKE2 and Rancher state. RKE2 snapshots it every 12 hours to
`/var/lib/rancher/rke2/server/db/snapshots` and keeps 5; set `rke2_etcd_s3_bucket` to keep copies
off the host. Take one before an experiment and roll back afterwards (from `ansible/`):

```bash
./manage.sh snapshot before-test   # save, then list all snapshots
./manage.sh snapshots
./manage.sh restore before-test    # about 3 minutes; Rancher is down meanwhile
```

`restore` takes the newest snapshot whose name starts with the one given. It rolls back Rancher,
Fleet and everything on the Rancher cluster. The kind clusters keep running and reconnect; Fleet
then redeploys the apps it had at snapshot time, but other workloads inside them are not restored.

**Settings:** [RKE2 and etcd snapshots](configuration.md#rke2-and-etcd-snapshots).
