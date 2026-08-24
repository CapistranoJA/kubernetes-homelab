#!/bin/sh
set -eu

INVENTORY="${INVENTORY:-/run/media/capistranoja/Shared/_Personal/Labs/tenno-cluster/kubernetes-homelab/ansible/inventory.yaml}"

VMS=$(
  ansible-inventory -i "$INVENTORY" --list |
    jq -r '
      ._meta.hostvars
      | keys[]
    '
)
for vm in $VMS; do
  sudo virsh -c qemu:///system destroy "$vm" 2>/dev/null || true
done