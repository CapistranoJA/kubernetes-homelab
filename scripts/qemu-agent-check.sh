#!/bin/sh
set -eu

INVENTORY="${INVENTORY:-/data/_Personal/Labs/tenno-cluster/kubernetes-homelab/ansible/inventory.yaml}"

VMS=$(
  ansible-inventory -i "$INVENTORY" --list |
    jq -r '
      ._meta.hostvars
      | keys[]
    '
)
for vm in $VMS; do
  sudo virsh -c qemu:///system domifaddr "$vm" --source agent 2>/dev/null || true
done
