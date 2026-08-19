#!/bin/sh

# Backup current config
cp ~/.kube/config ~/.kube/config.backup

# Merge, with admin.conf first
KUBECONFIG=~/.kube/admin.conf:~/.kube/config \
kubectl config view --flatten --merge > /tmp/kubeconfig

mv /tmp/kubeconfig ~/.kube/config
chmod 600 ~/.kube/config