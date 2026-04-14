#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_INVENTORY="${SCRIPT_DIR}/../terraform/generated/hosts.yml"

# --- Help/Usage ---
usage() {
    echo "Usage: $0 <command> [ansible-options]"
    echo ""
    echo "Commands:"
    echo "  install    Install Ansible collections from requirements.yml"
    echo "  deploy     Run the main deployment playbook."
    echo "             Any extra arguments are passed to ansible-playbook."
    echo "             Examples:"
    echo "               ./manage.sh deploy                              # uses inventory/hosts.yml"
    echo "               ./manage.sh deploy -i /path/to/custom-inv.yml  # any inventory"
    echo "               ./manage.sh deploy -i ../terraform/generated/hosts.yml  # Terraform-provisioned AWS host"
    echo "  destroy    Delete all clusters and cleanup kubeconfigs on all hosts."
    echo "  status     Run cluster-status script on all hosts."
    echo "  help       Show this help message."
    echo ""
    echo "Note: Ansible is a standalone building block. Terraform is one way to provision"
    echo "a machine — but you can point this playbook at any host via -i or inventory/hosts.yml."
}

# --- Main Logic ---
COMMAND=$1
shift || true

if [ -z "$COMMAND" ]; then
    usage
    exit 1
fi

case $COMMAND in
    install)
        echo ">>> Installing Ansible collections..."
        cd "${SCRIPT_DIR}"
        ansible-galaxy collection install -r requirements.yml
        echo ">>> Installation complete."
        ;;
    deploy)
        echo ">>> Running deployment playbook..."
        cd "${SCRIPT_DIR}"
        unset ANSIBLE_VAULT_PASSWORD_FILE
        ansible-playbook main.yml "$@"
        ;;
    destroy)
        echo ">>> Removing Rancher and cert-manager on all hosts..."
        cd "${SCRIPT_DIR}"
        ansible all -i inventory/hosts.yml -m shell -a "/usr/local/bin/cleanup-rancher" "$@"
        ;;
    status)
        echo ">>> Getting status from all hosts..."
        cd "${SCRIPT_DIR}"
        ansible all -i inventory/hosts.yml -m shell -a "/usr/local/bin/cluster-status" "$@"
        ;;
    help|--help|-h)
        usage
        ;;
    *)
        echo "Error: Unknown command '$COMMAND'"
        usage
        exit 1
        ;;
esac
