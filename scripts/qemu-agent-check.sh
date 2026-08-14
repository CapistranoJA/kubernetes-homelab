#!/bin/sh

for vm in lotus excalibur-prime mag-prime volt-prime; do
  echo "=== $vm ==="
  sudo virsh -c qemu:///system domifaddr "$vm" --source agent
done