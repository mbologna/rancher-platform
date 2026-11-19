# Image cache

Repeated resets and new kind clusters pull the same images again, and Docker Hub limits anonymous
pulls. `registry_cache_enabled: true` runs a pull-through cache on the host for docker.io,
ghcr.io, quay.io and registry.k8s.io, on ports 5001-5004. RKE2 and the downstream clusters pull
through it and go to the upstream registry when it is down. The images stay in Docker volumes
`rp-registry-*` when the cache is turned off; `reset` deletes them. Set
`registry_cache_dockerhub_username` and `registry_cache_dockerhub_password` in `secrets.yml` to
pull from Docker Hub as that account; an access token works as the password.

**Settings:** [Image cache](configuration.md#image-cache).
