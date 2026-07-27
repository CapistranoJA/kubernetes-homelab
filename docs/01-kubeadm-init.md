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

```yaml
apiVersion: kubeadm.k8s.io/v1beta4
kind: ClusterConfiguration
kubernetesVersion: v1.36.0
controlPlaneEndpoint: "192.168.160.150:6443"
networking:
  podSubnet: "10.244.0.0/16"
---
apiVersion: kubeadm.k8s.io/v1beta4
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: "192.168.160.150"
  bindPort: 6443
```
### Run Init

```bash
sudo kubeadm init --config kubeadm-config.yaml
```

### Post-Init: Save the Join Command

`kubeadm init` prints a `kubeadm join` command with a token and cert hash at the end of its output. Copy this somewhere safe, it's needed for Mag and Volt below.
 
If it's lost or the token has expired (tokens expire after 24h by default), regenerate it from Excalibur:
 
```bash
kubeadm token create --print-join-command
```

### Post-Init: kubeconfig Setup

`admin.conf` is generated on Excalibur during `kubeadm init`, but running `kubectl` directly on the control-plane node isn't ideal, it means every cluster operation requires an SSH session, and keeps the admin credential's only copy sitting on the same node running the control plane itself.
 
Instead, copy it off to your local workstation and manage the cluster remotely:
 
```bash
# Run this on controller node without sudo access
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Run this on your LOCAL machine, not on Excalibur
scp -P 2222 -i devops@192.168.160.150:/home/devops/.kube/config ~/.kube/config
```
 
> **Note:** This assumes SSH is configured per 00-prerequisites.md (key-based auth, port 2222). Once copied, `kubectl` commands run directly from your local machine against the cluster, no SSH session needed for routine operations.
 
 
## Installing the CNI (Pod Network)

> **Note:** 00-prerequisites.md installed the low-level CNI plugin binaries (containernetworking/plugins) required by containerd, but a CNI network provider (the actual pod networking implementation) still needs to be deployed separately. This project uses **Calico**.
>
> **Alternative:** Cilium is a popular alternative that uses eBPF instead of iptables for its dataplane, offering better performance at scale and built-in observability (Hubble). Calico was chosen here for its maturity and simpler operational model.
 
### Calico Prerequisites
 
Before installing, confirm the following on all 3 nodes (per [Calico's system requirements](https://docs.tigera.io/calico/latest/getting-started/kubernetes/requirements)):
 
- [x] Kernel ≥ 5.10 — Ubuntu 24.04 satisfies this by default, no action needed
- [x] No competing iptables manager (firewalld, etc.) — not applicable here, this project uses UFW throughout
- [x] NetworkManager isn't managing Calico's interfaces — if NetworkManager is present on the nodes, it needs to be configured to ignore `cali*`, `tunl*` (IPIP), and `vxlan.calico` (VXLAN) interfaces, otherwise it may interfere with Calico's networking
- [x] UFW allows Calico's required ports (see below)

**Additional UFW rules needed (all 3 nodes)**:
 
```bash
# BGP - Calico's routing protocol between nodes
sudo ufw allow 179/tcp
```
> **Note:** These ports aren't covered by the role-specific UFW rules in [00-prerequisites.md](00-prerequisites.md#4-firewall---noderole-specific-ports), since those only cover core Kubernetes control-plane/kubelet ports, not CNI-specific traffic. If Calico is later switched from IPIP to VXLAN mode, `sudo ufw allow 4789/udp` would replace the `ipip` rule instead.
## Joining Worker Nodes

## Verifying Cluster Health

## Verification
