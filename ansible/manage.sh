#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIMA_INVENTORY="${SCRIPT_DIR}/inventory/lima.yml"
TERRAFORM_INVENTORY="${SCRIPT_DIR}/../terraform/generated/hosts.yml"
cd "${SCRIPT_DIR}"

usage() {
    cat <<USAGE
Usage: $0 <command> [ansible options]

Commands:
  install            Install the Ansible collections from requirements.yml
  deploy             Install or update RKE2, cert-manager and Rancher (idempotent)
  reset              Wipe RKE2/k3s/kind/k3d and all Docker data, then deploy from scratch
  status             Show nodes, Rancher clusters, Fleet apps and unhealthy pods
  kubeconfig         Write a fresh kubeconfig to ~/.kube/rancher-platform.yaml
  snapshot [name]    Save an etcd snapshot of RKE2 and Rancher (default name: manual)
  snapshots          List etcd snapshots
  restore <name>     Restore RKE2 and Rancher from a snapshot, local or in S3 (kind clusters keep running)
  uninstall-rancher  Remove Rancher, Rancher AI and cert-manager (RKE2 stays)
  help               Show this help

Extra options are passed to Ansible, e.g.:
  $0 deploy -i /path/to/inventory.yml
  $0 deploy -e '{"downstream_clusters": ["dev"]}'

Inventory: inventory/hosts.yml if present, else inventory/lima.yml (written by
../local/lima.sh up), else ../terraform/generated/hosts.yml.
USAGE
}

# Sets INV, unless the user passes -i or has a hand-written inventory/hosts.yml (ansible.cfg's
# default): the Lima VM's inventory while it exists, else the Terraform-generated one.
# (Written for bash 3.2, the macOS default: no mapfile, guarded empty-array expansion.)
INV=()
set_inventory() {
    local arg inventory
    for arg in "$@"; do
        case "${arg}" in -i | --inventory | --inventory=* | -i*) return ;; esac
    done
    [[ -f inventory/hosts.yml ]] && return
    for inventory in "${LIMA_INVENTORY}" "${TERRAFORM_INVENTORY}"; do
        if [[ -f "${inventory}" ]]; then
            echo "Inventory: ${inventory#"${SCRIPT_DIR}/"}" >&2
            INV=(-i "${inventory}")
            return
        fi
    done
}

# Prompts for the vault password when secrets.yml is encrypted and no password source is configured.
VAULT=()
set_vault() {
    local arg
    [[ -n "${ANSIBLE_VAULT_PASSWORD_FILE:-}" || -n "${ANSIBLE_VAULT_IDENTITY_LIST:-}" ]] && return
    for arg in "$@"; do
        case "${arg}" in --vault-* | --ask-vault-pass | -J) return ;; esac
    done
    if [[ "$(head -c 14 group_vars/all/secrets.yml 2>/dev/null)" == "\$ANSIBLE_VAULT" ]]; then
        VAULT=(--ask-vault-pass)
    fi
}

playbook() {
    set_inventory "$@"
    set_vault "$@"
    ansible-playbook main.yml ${INV[@]+"${INV[@]}"} ${VAULT[@]+"${VAULT[@]}"} "$@"
}

COMMAND=${1:-}
shift || true

case "${COMMAND}" in
    install)
        ansible-galaxy collection install -r requirements.yml
        ;;
    deploy)
        playbook "$@"
        ;;
    reset)
        playbook -e reset=true "$@"
        ;;
    status)
        # Only the always-tagged bootstrap and summary run.
        playbook --tags status "$@"
        ;;
    kubeconfig)
        playbook --tags kubeconfig -e kubeconfig_refresh=true "$@"
        ;;
    snapshot)
        name=manual
        [[ $# -gt 0 && "$1" != -* ]] && { name=$1; shift; }
        playbook --tags snapshot,snapshots -e etcd_snapshot_name="${name}" "$@"
        ;;
    snapshots)
        playbook --tags snapshots "$@"
        ;;
    restore)
        [[ $# -gt 0 && "$1" != -* ]] || { echo "Usage: $0 restore <name> [ansible options]" >&2; exit 1; }
        name=$1
        shift
        playbook --tags restore -e etcd_snapshot_name="${name}" "$@"
        ;;
    uninstall-rancher)
        playbook --tags uninstall "$@"
        ;;
    help | --help | -h)
        usage
        ;;
    *)
        usage >&2
        exit 1
        ;;
esac
