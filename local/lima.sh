#!/usr/bin/env bash
# Creates or deletes a Lima VM for rancher-platform and writes its Ansible inventory.
set -euo pipefail

NAME=${LIMA_INSTANCE:-rancher-platform}
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INVENTORY="${DIR}/../ansible/inventory/lima.yml"

case "${1:-}" in
    up)
        if ! limactl list --quiet | grep -qx "${NAME}"; then
            limactl create --tty=false --name "${NAME}" "${DIR}/lima.yaml"
        fi
        [[ "$(limactl list --format '{{.Status}}' "${NAME}")" == Running ]] || limactl start --tty=false "${NAME}"
        ip=$(limactl shell "${NAME}" ip -4 -o addr show lima0 | awk '{split($4, a, "/"); print a[1]}')
        user=$(limactl shell "${NAME}" whoami)
        cat >"${INVENTORY}" <<INVENTORY
---
# Written by local/lima.sh for the Lima VM "${NAME}".
servers:
  hosts:
    ${NAME}:
      ansible_host: ${ip}
      ansible_user: ${user}
      ansible_ssh_private_key_file: ~/.lima/_config/user
      rancher_hostname: rancher.${ip}.sslip.io
INVENTORY
        echo "VM ${NAME} is at ${ip}. Deploy with: cd ansible && ./manage.sh deploy -i inventory/lima.yml"
        ;;
    down)
        limactl delete --force "${NAME}"
        rm -f "${INVENTORY}"
        ;;
    *)
        echo "Usage: $0 up|down" >&2
        exit 1
        ;;
esac
