#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_INVENTORY="${SCRIPT_DIR}/../terraform/generated/hosts.yml"
cd "${SCRIPT_DIR}"

usage() {
    cat <<USAGE
Usage: $0 <command> [ansible options]

Commands:
  install            Install the Ansible collections from requirements.yml
  deploy             Install or update RKE2, cert-manager and Rancher (idempotent)
  reset              Wipe RKE2/k3s/kind/k3d and all Docker data, then deploy from scratch
  status             Run cluster-status on all hosts
  uninstall-rancher  Remove Rancher and cert-manager (RKE2 stays)
  help               Show this help

Extra options are passed to Ansible, e.g.:
  $0 deploy -i /path/to/inventory.yml
  $0 deploy -e fleet_gitrepo_enabled=true

Inventory: inventory/hosts.yml if present, else ../terraform/generated/hosts.yml.
USAGE
}

# Sets INV: the Terraform-generated inventory, unless the user passes -i or has a hand-written one.
# (Written for bash 3.2, the macOS default: no mapfile, guarded empty-array expansion.)
INV=()
set_inventory() {
    local arg
    for arg in "$@"; do
        case "${arg}" in -i | --inventory | --inventory=* | -i*) return ;; esac
    done
    if [[ ! -f inventory/hosts.yml && -f "${TERRAFORM_INVENTORY}" ]]; then
        INV=(-i "${TERRAFORM_INVENTORY}")
    fi
}

run_on_hosts() {
    local script=$1
    shift
    set_inventory "$@"
    ansible servers ${INV[@]+"${INV[@]}"} --become -m ansible.builtin.command -a "/usr/local/bin/${script}" "$@"
}

COMMAND=${1:-}
shift || true

case "${COMMAND}" in
    install)
        ansible-galaxy collection install -r requirements.yml
        ;;
    deploy | reset)
        set_inventory "$@"
        [[ "${COMMAND}" == reset ]] && set -- -e reset=true "$@"
        ansible-playbook main.yml ${INV[@]+"${INV[@]}"} "$@"
        ;;
    status)
        run_on_hosts cluster-status "$@"
        ;;
    uninstall-rancher)
        run_on_hosts uninstall-rancher "$@"
        ;;
    help | --help | -h)
        usage
        ;;
    *)
        usage >&2
        exit 1
        ;;
esac
