# 01 Kubeadm Init
This document covers bootstrapping the Kubernetes control plane on **Excalibur**, joining **Mag** and **Volt** as worker nodes, and installing the CNI to bring the cluster to a fully `Ready` state.
 
> Before starting, confirm all items in [00 - Prerequisites](00-prerequisites.md#verification) are checked off on all 3 nodes.
 
## Initializing Control Plane
Run on **Excalibur** only.
 
> **Note:** A declarative `kubeadm-config.yaml` is used here instead of inline CLI flags. This keeps the exact cluster configuration versioned and reviewable in the repo, rather than buried in a one-off command, and scales more cleanly if the control plane is later extended (e.g. adding HA control-plane nodes, custom feature gates) without needing to reconstruct a growing pile of flags.

### kubeadm-config.yaml

Generate the default config and edit only what's needed:
 
```bash
kubeadm config print init-defaults > kubeadm-config.yaml
```
Edit `kubeadm-config.yaml` and update the needed fields.
### Run Init

### Post-Init: Save the Join Command

### Post-Init: kubeconfig Setup

## Installing the CNI (Pod Network)

## Joining Worker Nodes

## Verifying Cluster Health

## Verification
