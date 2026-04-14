#!/bin/bash
set -e

# --- Help/Usage ---
usage() {
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  install    Install Ansible collections from requirements.yml"
    echo "  deploy     Run the main deployment playbook."
    echo "  destroy    Delete all clusters and cleanup kubeconfigs on all hosts."
    echo "  status     Run cluster-status script on all hosts."
    echo "  help       Show this help message."
}

# --- Main Logic ---
COMMAND=$1
shift || true # Shift arguments to process options

# Check for command
if [ -z "$COMMAND" ]; then
    usage
    exit 1
fi

# Execute command
case $COMMAND in
    install)
        echo ">>> Installing Ansible collections..."
        ansible-galaxy collection install -r requirements.yml
        echo ">>> Installation complete."
        ;;
    deploy)
        echo ">>> Running deployment playbook..."
        unset ANSIBLE_VAULT_PASSWORD_FILE
        ansible-playbook main.yml "$@"
        ;;
    destroy)
        echo ">>> Removing Rancher and cert-manager on all hosts..."
        ansible all -i inventory/hosts.yml -m shell -a "/usr/local/bin/cleanup-rancher"
        ;;
    status)
        echo ">>> Getting status from all hosts..."
        ansible all -i inventory/hosts.yml -m shell -a "/usr/local/bin/cluster-status"
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
