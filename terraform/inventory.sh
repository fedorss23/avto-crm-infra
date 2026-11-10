#!/bin/bash

# Получаем значения из Terraform output
VM_INTERNAL_IP=$(terraform output -raw vm_internal_ip 2>/dev/null)
EXTERNAL_IP=$(terraform output -raw external_ip 2>/dev/null)

if [ -z "$VM_INTERNAL_IP" ] || [ -z "$EXTERNAL_IP" ]; then
    echo "Ошибка: не удалось получить IP адреса. Запустите terraform apply" >&2
    exit 1
fi

cat << EOF
all:
  hosts:
    evo-vm:
      ansible_host: ${EXTERNAL_IP}
      ansible_user: ubuntu
      ansible_python_interpreter: auto_silent
      ansible_ssh_private_key_file: ~/.ssh/id_rsa_agent
      ansible_ssh_common_args: '-o StrictHostKeyChecking=no'
  children:
    cloudru_evolution:
      hosts:
        evo-vm:
          internal_ip: ${VM_INTERNAL_IP}
EOF
