# App of apps

## What is app of apps

Instead of manually creating each application in ArgoCD, we create a single **root/parent** application that manages the child applications. In this case git will be the source of truth, and ArgoCD will recursively deploy application inside the repository that the root application can see.

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

Currently our installation of ArgoCD is via downloading manifests and kubectl apply. This means that if we have changes in ArgoCD it will not go through git but instead manually. While the current setup works, to fully utilize ArgoCD and to excersise gitops we will need to make ArgoCD self managed so that any changes will go through git. 

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
        - argocd-values.yaml
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

## Verification

- [x] All pods in `argocd` are `Running` (`kubectl get pods -n argocd`)
- [x] ArgoCD Application itself is `Synced`/`Healthy`
- [x] A Root Application syncs successfully and reports `Synced`/`Healthy`
