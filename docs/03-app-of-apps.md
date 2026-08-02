# App of apps

## What is app of apps

Instead of manually creating each application in ArgoCD, we create a single **root/parent** application that manages the child applications. In this case git will be the source of truth, and ArgoCD will apply the child Application resources defined in the repository. These child applications will then manage their own resources.

## Root application yaml

This yaml will be manually applied so that App of apps pattern can begin. After manually applying the root application's yaml, it will manage the directory it's pointed to. This will mean that all changes are made through Git. ArgoCD will detect the commits, synchronizes the updated manifests, and reconciles the cluster automatically. It will eliminate the need for manual installation of services.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root-application
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/CapistranoJA/kubernetes-homelab.git
    targetRevision: HEAD
    path: apps/bootstrap

  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
    automated:
      enabled: true
      prune: true
      selfHeal: true
```

## Self-managed Argocd

Currently our installation of ArgoCD is via downloading manifests and kubectl apply. This means that if we have changes in ArgoCD it will not go through git but instead needs to be applied. While the current setup works, to fully utilize ArgoCD and to excersise gitops we will need to make ArgoCD self managed so that any changes will go through git. 

Below shows the `ArgoCD` application definition.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: argocd
  namespace: argocd
spec:
  project: default
  source:
    chart: argo/argo-cd
    repoURL: https://argoproj.github.io/argo-helm
    targetRevision: 10.2.2
    helm:
      releaseName: argocd
      valueFiles:
        - ../values/argocd/argocd-values.yaml
      ignoreMissingValueFiles: true 

  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
    automated:
      enabled: true
      prune: true
      selfHeal: true
```
For now we will leave argocd-values.yaml empty. This will be filled up later once the ingress has been implemented.

## Recreating Gitops

To apply the changes to our CD pipeline, we will need to remove the current ArgoCD installation and recreate it through the ArgoCD Helm chart. It is possible to continue from the current installation, but starting from scratch provides a cleaner transition since ArgoCD will now be managed through git.

```bash
# Remove current argocd installation
kubectl delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# add argocd repository
helm repo add argo https://argoproj.github.io/argo-helm

# Install argocd
helm install argocd argo/argo-cd --version 10.2.2 --namespace argocd --create-namespace
```
After installing ArgoCD through Helm, we can now apply the bootstrap.yaml.

```bash
kubectl apply -f root-app.yaml
```

>**Note**: Make sure the changes are committed and pushed to Git first. ArgoCD will use the repository as the source of truth.

## Verification

- [x] All pods in `argocd` are `Running` (`kubectl get pods -n argocd`)
- [x] ArgoCD Application itself is `Synced`/`Healthy`
- [x] A Root Application syncs successfully and reports `Synced`/`Healthy`
