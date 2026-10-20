# Changelog

## [2.0.0](https://github.com/mbologna/rancher-platform/compare/v1.1.0...v2.0.0) (2026-10-20)


### ⚠ BREAKING CHANGES

* hosts deployed with rke2_ingress_controller: ingress-nginx switch to Traefik on the next deploy; RKE2 restarts and the Rancher Ingress moves to class traefik.
* fleet_gitrepo_enabled and the cluster-status, rancher-logs and port-forward-rancher host scripts are removed.

### Features

* add an optional registry pull-through cache for RKE2 and the kind clusters ([#51](https://github.com/mbologna/rancher-platform/issues/51)) ([28398da](https://github.com/mbologna/rancher-platform/commit/28398da90d4088ae066fea85f470cf99a1dc44e5))
* add helm_charts list with monitoring and backup presets, and metrics-server on kind ([#50](https://github.com/mbologna/rancher-platform/issues/50)) ([40b147a](https://github.com/mbologna/rancher-platform/commit/40b147aced19b9a3e9146a055db29a78a902e392))
* add Kubewarden, Longhorn and Harbor chart presets ([#54](https://github.com/mbologna/rancher-platform/issues/54)) ([35c8f29](https://github.com/mbologna/rancher-platform/commit/35c8f29ac22cd30577db8833869126565215bf47))
* add snapshot, snapshots and restore commands ([#46](https://github.com/mbologna/rancher-platform/issues/46)) ([b9d473c](https://github.com/mbologna/rancher-platform/commit/b9d473c6100f08034ca44fea57c0b04e45474acb))
* expose Fleet apps through Ingress and remove dropped cluster labels ([#49](https://github.com/mbologna/rancher-platform/issues/49)) ([559ff0c](https://github.com/mbologna/rancher-platform/commit/559ff0cd175fa867f0c38af1b8ef360bac98d2f5))
* let Rancher provision RKE2 clusters on Docker-container nodes ([#53](https://github.com/mbologna/rancher-platform/issues/53)) ([223e508](https://github.com/mbologna/rancher-platform/commit/223e5089c3e5eae56178e23acdd8c430202f6beb))
* run Rancher release candidates, nightly builds and settings ([#48](https://github.com/mbologna/rancher-platform/issues/48)) ([fccff0b](https://github.com/mbologna/rancher-platform/commit/fccff0b571da1b832c5c59ca0d86122f5fc8ded6))


### Bug Fixes

* restart workloads after an etcd restore ([#47](https://github.com/mbologna/rancher-platform/issues/47)) ([8e4e88e](https://github.com/mbologna/rancher-platform/commit/8e4e88e145ba47aaaf5ef539fd58a577a0de1228))


### Code Refactoring

* drop host helper scripts and fold fleet_gitrepo into fleet_apps ([#44](https://github.com/mbologna/rancher-platform/issues/44)) ([5bc6a46](https://github.com/mbologna/rancher-platform/commit/5bc6a462c35d7c96301f7e39012ae7c2f74c91bb))
* drop the ingress-nginx option and always use Traefik ([#52](https://github.com/mbologna/rancher-platform/issues/52)) ([62b4264](https://github.com/mbologna/rancher-platform/commit/62b4264d21c8fae29ed340d1b8a7d7e732bd947d))

## [1.1.0](https://github.com/mbologna/rancher-platform/compare/v1.0.0...v1.1.0) (2026-10-18)


### Features

* add a Lima VM for local deploys ([#25](https://github.com/mbologna/rancher-platform/issues/25)) ([701efb8](https://github.com/mbologna/rancher-platform/commit/701efb8d19d24d3974bcc54d671857931e0a546a))
* **ansible:** add manage.sh kubeconfig ([#20](https://github.com/mbologna/rancher-platform/issues/20)) ([7d40fc3](https://github.com/mbologna/rancher-platform/commit/7d40fc36ec11da2a46ce4371f6a411758776c920))
* **ansible:** configure etcd snapshots and optional S3 upload ([#19](https://github.com/mbologna/rancher-platform/issues/19)) ([61409ac](https://github.com/mbologna/rancher-platform/commit/61409ace17e2a6c0a7f0a520dae3018084517ab5))
* **capi:** add capd_enabled for hosts that already run Docker ([#30](https://github.com/mbologna/rancher-platform/issues/30)) ([e9dd2ad](https://github.com/mbologna/rancher-platform/commit/e9dd2adecb42a869394aba0dc6191ceded08bd55))
* default rancher_hostname to the host's DNS name and follow changes ([#40](https://github.com/mbologna/rancher-platform/issues/40)) ([f5cd667](https://github.com/mbologna/rancher-platform/commit/f5cd6675b7f2f3f8c1077cb67f9ef766f48b6cfc))
* deploy apps to every cluster with Fleet ([#43](https://github.com/mbologna/rancher-platform/issues/43)) ([16c1c89](https://github.com/mbologna/rancher-platform/commit/16c1c89c9000512310806c7e6e811b318f7e5aa4))
* optional kind downstream clusters imported into Rancher ([#31](https://github.com/mbologna/rancher-platform/issues/31)) ([c67e41f](https://github.com/mbologna/rancher-platform/commit/c67e41f65d2e1e52b9bbbe03e7cdbced67d98697))
* pick the Kubernetes version of each downstream cluster ([#42](https://github.com/mbologna/rancher-platform/issues/42)) ([9b82ef2](https://github.com/mbologna/rancher-platform/commit/9b82ef28c1566c6620c416fd6b2ba461fcbe08b8))
* **terraform:** encrypt the root EBS volume ([#18](https://github.com/mbologna/rancher-platform/issues/18)) ([53c583f](https://github.com/mbologna/rancher-platform/commit/53c583f2469d1bcff4c145045af66834f4cde43a))


### Bug Fixes

* **ansible:** keep the fetched kubeconfig private ([#27](https://github.com/mbologna/rancher-platform/issues/27)) ([7ee3edf](https://github.com/mbologna/rancher-platform/commit/7ee3edf5a5d0f7cf4f432780e8215d6690cc3e65))
* name kubeconfig contexts after the host ([#33](https://github.com/mbologna/rancher-platform/issues/33)) ([a4007e2](https://github.com/mbologna/rancher-platform/commit/a4007e20e91ce40930fd61885c0092e514125367))
* reach clusters through Rancher and survive uninstall-rancher ([#32](https://github.com/mbologna/rancher-platform/issues/32)) ([d21753e](https://github.com/mbologna/rancher-platform/commit/d21753e09ab1b55fe3f2e00e904a94539f256f05))
* refuse foreign RKE2/K3s installs and set Rancher's server URL ([#29](https://github.com/mbologna/rancher-platform/issues/29)) ([9153a38](https://github.com/mbologna/rancher-platform/commit/9153a3805b739dd304ce5721f064b71175b29b5a))
