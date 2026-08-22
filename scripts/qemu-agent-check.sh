#!/bin/sh
set -eu

INVENTORY="${INVENTORY:-../ansible/inventory.yaml}"

VMS=$(
  ansible-inventory -i "$INVENTORY" --list |
    jq -r '
      .tenno_cluster.children[]
      as $group
      | .[$group].hosts[]
    '
)
for vm in $VMS; do
  sudo virsh -c qemu:///system domifaddr "$vm" --source agent
done
