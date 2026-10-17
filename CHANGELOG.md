# Changelog

## [1.1.0](https://github.com/mbologna/rancher-platform/compare/v1.0.0...v1.1.0) (2026-10-17)


### Features

* add a Lima VM for local deploys ([#25](https://github.com/mbologna/rancher-platform/issues/25)) ([701efb8](https://github.com/mbologna/rancher-platform/commit/701efb8d19d24d3974bcc54d671857931e0a546a))
* **ansible:** add manage.sh kubeconfig ([#20](https://github.com/mbologna/rancher-platform/issues/20)) ([7d40fc3](https://github.com/mbologna/rancher-platform/commit/7d40fc36ec11da2a46ce4371f6a411758776c920))
* **ansible:** configure etcd snapshots and optional S3 upload ([#19](https://github.com/mbologna/rancher-platform/issues/19)) ([61409ac](https://github.com/mbologna/rancher-platform/commit/61409ace17e2a6c0a7f0a520dae3018084517ab5))
* **capi:** add capd_enabled for hosts that already run Docker ([#30](https://github.com/mbologna/rancher-platform/issues/30)) ([e9dd2ad](https://github.com/mbologna/rancher-platform/commit/e9dd2adecb42a869394aba0dc6191ceded08bd55))
* optional kind downstream clusters imported into Rancher ([#31](https://github.com/mbologna/rancher-platform/issues/31)) ([c67e41f](https://github.com/mbologna/rancher-platform/commit/c67e41f65d2e1e52b9bbbe03e7cdbced67d98697))
* **terraform:** encrypt the root EBS volume ([#18](https://github.com/mbologna/rancher-platform/issues/18)) ([53c583f](https://github.com/mbologna/rancher-platform/commit/53c583f2469d1bcff4c145045af66834f4cde43a))


### Bug Fixes

* **ansible:** keep the fetched kubeconfig private ([#27](https://github.com/mbologna/rancher-platform/issues/27)) ([7ee3edf](https://github.com/mbologna/rancher-platform/commit/7ee3edf5a5d0f7cf4f432780e8215d6690cc3e65))
* refuse foreign RKE2/K3s installs and set Rancher's server URL ([#29](https://github.com/mbologna/rancher-platform/issues/29)) ([9153a38](https://github.com/mbologna/rancher-platform/commit/9153a3805b739dd304ce5721f064b71175b29b5a))
