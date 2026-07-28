# 02 ArgoCD

This document covers installing ArgoCD into the cluster and transitioning from imperative Kubernetes deployments to a GitOps workflow where Git becomes the source of truth for cluster state.

> **Note:** This document assumes the cluster from [01 - Kubeadm Init](01-kubeadm-init.md#verification) is fully operational and all nodes are in the `Ready` state.

## Why ArgoCD?

Everything so far has been `kubectl apply -f` by hand. That's fine working solo, but there's no
record of what changed or when, and if something drifts (a manual `kubectl edit` to
unblock something) nothing catches it. The cluster and whatever's in the repo just
quietly disagree.

ArgoCD watches a git repo and keeps the cluster in sync with it. Push to git, ArgoCD
applies it. Also sets up app-of-apps later. one Application managing all the others
(Harbor, cert-manager, etc.) instead of installing each by hand.

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
### Accessing ArgoCD UI

During initial setup, ArgoCD was accessed using Kubernetes port forwarding.

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

The web interface is then available at:

```
https://localhost:8080
```
### Retrieve the initial admin password
 
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```
### Login via UI 
You can visit https://localhost:8080. By default the TLS Certificates that argocd uses are self-signed, the implementation of a custom ssl certificate will be added later on.

You can also login via CLI using
```bash
argocd login localhost:8080 --username admin --password <password-from-previous step> --insecure
```

Change the password immediately after first login:
 
```bash
argocd account update-password
```
## Verification
Before proceeding to the next doc, confirm:

- [x] All pods in `argocd` are `Running` (`kubectl get pods -n argocd`)
- [x] `argocd account get-user-info` succeeds via CLI
- [x] UI loads at `https://localhost:8080` and shows an empty Applications dashboard
- [ ] A test Application syncs successfully and reports `Synced`/`Healthy`
