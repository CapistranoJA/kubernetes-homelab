#!/bin/sh
set -eu

INVENTORY="${INVENTORY:-/run/media/capistranoja/Shared/_Personal/Labs/tenno-cluster/kubernetes-homelab/ansible/inventory.yaml}"

VMS=$(
  ansible-inventory -i "$INVENTORY" --list |
    jq -r '
      .tenno_cluster.children[]
      as $group
      | .[$group].hosts[]
    '
)
for vm in $VMS; do
  sudo virsh -c qemu:///system start "$vm"
done