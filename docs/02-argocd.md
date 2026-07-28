# 02 ArgoCD

This document covers installing ArgoCD into the cluster and transitioning from imperative Kubernetes deployments to a GitOps workflow where Git becomes the source of truth for cluster state.

> **Note:** This document assumes the cluster from [01 - Kubeadm Init](01-kubeadm-init.md#verification) is fully operational and all nodes are in the `Ready` state.

## Why ArgoCD?

## Installing ArgoCD
Refer to the [Official ArgoCD Docs](https://argo-cd.readthedocs.io/en/stable/getting_started/) for a more detailed explanation.

### Create the namespace and install manifest
 
```bash
kubectl create ns argocd

kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```
> **Note:** The `--server-side` flag is required because some ArgoCD resources (most notably the `ApplicationSet` CRD) exceed Kubernetes' 262 KB annotation limit when applied using client-side `kubectl apply`. Server-side apply avoids this limitation by storing field ownership in `managedFields` instead of the `kubectl.kubernetes.io/last-applied-configuration` annotation.

### Verify Installation

```bash
kubectl get pods -n argocd
```

### Install the ArgoCD CLI
 
On your workstation (not a cluster node):
 
```bash
# You can use homebrew to install argocli. Otherwise see notes 
brew install argocd
argocd version --client
```

## Verification


