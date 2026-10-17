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
  kubeconfig         Fetch the kubeconfig to ~/.kube/rancher-platform.yaml
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

# run_module <module> <args> [ansible options]: runs one module on all servers as root.
run_module() {
    local module=$1 args=$2
    shift 2
    set_inventory "$@"
    set_vault "$@"
    ansible servers ${INV[@]+"${INV[@]}"} ${VAULT[@]+"${VAULT[@]}"} --become -m "${module}" -a "${args}" "$@"
}

COMMAND=${1:-}
shift || true

case "${COMMAND}" in
    install)
        ansible-galaxy collection install -r requirements.yml
        ;;
    deploy | reset)
        set_inventory "$@"
        set_vault "$@"
        [[ "${COMMAND}" == reset ]] && set -- -e reset=true "$@"
        ansible-playbook main.yml ${INV[@]+"${INV[@]}"} ${VAULT[@]+"${VAULT[@]}"} "$@"
        ;;
    status)
        run_module ansible.builtin.command /usr/local/bin/cluster-status "$@"
        ;;
    kubeconfig)
        # shellcheck disable=SC2016 # Ansible expands the {{ }} variables from group_vars.
        run_module ansible.builtin.fetch 'src={{ rke2_kubeconfig_external }} dest={{ local_kubeconfig }} flat=true' "$@"
        ;;
    uninstall-rancher)
        run_module ansible.builtin.command /usr/local/bin/uninstall-rancher "$@"
        ;;
    help | --help | -h)
        usage
        ;;
    *)
        usage >&2
        exit 1
        ;;
esac
