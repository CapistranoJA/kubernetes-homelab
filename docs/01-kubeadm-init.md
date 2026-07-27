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
nodeRegistration:
  name: excalibur
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

### Install Calico (Tigera Operator, eBPF dataplane)
 
This project uses the **Tigera Operator** install method rather than the older raw-manifest approach, the operator manages Calico's CRDs and lifecycle declaratively via an `Installation` custom resource, rather than requiring manual edits to DaemonSet env vars.
 
**1. Install the Tigera Operator and CRDs**
 
```bash
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.32.1/manifests/v1_crd_projectcalico_org.yaml

kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.32.1/manifests/tigera-operator.yaml
```
 
**2. Download the custom resources (eBPF dataplane)**
 
```bash
curl -O https://raw.githubusercontent.com/projectcalico/calico/v3.32.1/manifests/custom-resources-bpf.yaml

```
 
> **Note:** Calico's eBPF dataplane is used here instead of the traditional iptables default, for better performance and lower latency, similar to why Cilium defaults to eBPF. This is a more advanced/newer dataplane option compared to Calico's classic iptables mode.

**3. Set the pod CIDR in the custom resources manifest**
 
Before applying, edit `custom-resources-bpf.yaml` and set the pod IP pool to match this cluster's `podSubnet`:
 
```yaml
spec:
  calicoNetwork:
    ipPools:
    - name: default-ipv4-ippool
      cidr: 10.244.0.0/16
      encapsulation: VXLANCrossSubnet   
```
 
> **Note:** Unlike the older manifest-based install (which set `CALICO_IPV4POOL_CIDR` as a DaemonSet env var), the Operator method configures the pod IP pool declaratively through this `Installation` custom resource instead.
 
**4. Apply the manifest**
 
```bash
kubectl create -f custom-resources-bpf.yaml
```
 
**5. Monitor the deployment**
 
```bash
watch kubectl get tigerastatus
```
 
All components should show `True` under `AVAILABLE` after a few minutes:
 
```
NAME                            AVAILABLE   PROGRESSING   DEGRADED   SINCE
apiserver                       True        False         False      4m9s
calico                          True        False         False      3m29s
goldmane                        True        False         False      3m39s
ippools                         True        False         False      6m4s
kubeproxy-monitor               True        False         False      6m15s
whisker                         True        False         False      3m19s
```
 
### Verify Calico
 
```bash
kubectl get pods -n calico-system
```

All Calico pods should reach `Running`. Node status should flip from `NotReady` to `Ready` once the CNI is up:

```bash
kubectl get nodes
```
## Joining Worker Nodes

Run on **Mag** and **Volt**, using the join command saved from the control-plane init step:
 
```bash
sudo kubeadm join 192.168.160.150:6443 \
  --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash>
```
 
## Verifying Cluster Health

Run kubectl to check nodes:
 
```bash
# All 3 nodes should show STATUS = Ready
kubectl get nodes -o wide
 
# All system pods (kube-system + calico-system) should be Running
kubectl get pods -A
```
 
Optional deeper checks:
 
```bash
# Confirm kubelet is healthy on each node. Needs to SSH on each node
sudo systemctl status kubelet
 
# Confirm CoreDNS pods are running (2/2 by default)
kubectl get pods -n kube-system -l k8s-app=kube-dns
```

## Verification
Before proceeding to the next doc, confirm:
 
- [x] `kubectl get nodes` shows all 3 nodes as `Ready`
- [x] All pods in `kube-system` and `calico-system` are `Running`
- [x] CoreDNS pods are running and healthy

---
[← Back to index](index.md)