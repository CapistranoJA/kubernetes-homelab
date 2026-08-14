#!/bin/sh

for vm in lotus excalibur-prime mag-prime volt-prime; do
  sudo virsh -c qemu:///system start "$vm"
done