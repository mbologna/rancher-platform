#!/bin/bash
# Usage: kind-registry-mirrors.sh <node> [<registry>=<mirror URL> ...]
# Points containerd in a kind node at registry mirrors through /etc/containerd/certs.d, and removes
# the mirrors set by an earlier run that are no longer given. Prints "changed" when it edits the node.
set -euo pipefail
node=$1
shift
spec="$*"
dir=/etc/containerd/certs.d
state=$dir/.rancher-platform

current=$(docker exec "$node" cat "$state" 2>/dev/null || true)
[ "$current" = "$spec" ] && exit 0

# kind does not set config_path; containerd reads it only at start.
if [ -n "$spec" ] && ! docker exec "$node" grep -q "config_path = \"$dir\"" /etc/containerd/config.toml; then
  docker exec "$node" sh -c "printf '\n[plugins.\"io.containerd.grpc.v1.cri\".registry]\n  config_path = \"$dir\"\n' \
    >> /etc/containerd/config.toml && systemctl restart containerd"
fi

for m in $current; do
  docker exec "$node" rm -rf "$dir/${m%%=*}"
done
for m in $spec; do
  registry=${m%%=*}
  server=https://$registry
  [ "$registry" = docker.io ] && server=https://registry-1.docker.io
  printf 'server = "%s"\n\n[host."%s"]\n  capabilities = ["pull", "resolve"]\n' "$server" "${m#*=}" |
    docker exec -i "$node" sh -c "mkdir -p $dir/$registry && cat > $dir/$registry/hosts.toml"
done
if [ -n "$spec" ]; then
  echo "$spec" | docker exec -i "$node" sh -c "cat > $state"
else
  docker exec "$node" rm -f "$state"
fi
echo changed
