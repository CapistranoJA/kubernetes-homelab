# 00 - Prerequisites

This document covers node preparation in two parts:
> - **Part 1** is performed on the **template VM** before cloning — run once.
> - **Part 2** is performed on **each cloned node** (Excalibur, Mag, Volt) — run three times.

## VM Specs

| Node | Role | RAM | vCPU | Disk | Static IP |
|---|---|---|---|---|---|
| Excalibur | Controller | 4 GB | 4 | 50 GB | 192.168.160.150 |
| Mag | Worker | 8 GB | 4 | 50 GB | 192.168.160.151 |
| Volt | Worker | 8 GB | 4 | 50 GB | 192.168.160.152 |

## OS

- Ubuntu Server 24.04 LTS
- Network adapter: VMware NAT (VMnet8)
---

## Part 1: Node Preparation (Template VM)

Steps to harden and seal the template VM before cloning into Excalibur, Mag, and Volt.

### 1. Update System

```bash
sudo apt update && sudo apt upgrade -y
```


### 2. SSH Key Authentication

```bash
# Generate key pair on the Local machine (not the template)
ssh-keygen -t ed25519 -C "your-comment"

# Copy public key to template
ssh-copy-id -i ./keyname.pub devops@<template-ip>

```

### 3. Harden SSH

```bash
sudo vi /etc/ssh/sshd_config
```

Set the following:
```
PasswordAuthentication no
PermitRootLogin no
Port 2222
AllowUsers devops
```
Once config is changed, we can now test and restart the systemd unit.
```bash
#Test the config changes
sudo sshd -t 

#Below is needed to execute as per documentation(https://git.launchpad.net/ubuntu/+source/openssh/tree/debian/README.Debian#n184)
sudo systemctl daemon-reload  
sudo systemctl restart ssh.socket
sudo systemctl restart ssh
```
### 4. /etc/hosts Entries

All 3 nodes need to resolve each other by hostname:

```bash
sudo vi /etc/hosts
```
```
192.168.160.150  excalibur
192.168.160.151  mag
192.168.160.152  volt
```
### 5. Disable Swap

kubeadm requires swap to be disabled.

```bash
sudo swapoff -a

# Comment out swap entry in /etc/fstab to persist across reboot
sudo vi /etc/fstab
```
### 6. Kernel Modules & sysctl

```bash
# sysctl params required by setup, params persist across reboots
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
EOF

# load modules
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
EOF

# Load overlay module immediately without reboot
sudo modprobe overlay

# Apply sysctl params without reboot
sudo sysctl --system

# Verify that net.ipv4.ip_forward is set to 1 with:
sysctl net.ipv4.ip_forward

# Verify that overlay is loaded
lsmod | grep overlay
```
Note: **overlay** is explicitly loaded as Ubuntu 24.04 ships it as a loadable module (CONFIG_OVERLAY_FS=m) rather than built-in, which is required for containerd's default overlayfs snapshotter. **br_netfilter** is intentionally omitted since it was removed from kubeadm preflight checks and is the CNI's responsibility to configure if needed, per current K8s container runtime docs.

### 7. Install Container Runtime (containerd)

Installing containerd from official binaries. This includes containerd, runc, and CNI plugins.

**References:**
- [containerd releases](https://github.com/containerd/containerd/releases)
- [runc releases](https://github.com/opencontainers/runc/releases)
- [CNI plugins releases](https://github.com/containernetworking/plugins/releases)
- [containerd getting started](https://github.com/containerd/containerd/blob/main/docs/getting-started.md)

#### Step 1: Install containerd

```bash
# Download 2.3.2 — current LTS until April 30, 2028, compatible with k8s v1.36
curl -L -o /tmp/containerd-2.3.2-linux-amd64.tar.gz \
  https://github.com/containerd/containerd/releases/download/v2.3.2/containerd-2.3.2-linux-amd64.tar.gz

# Extract to /usr/local
sudo tar Cxzvf /usr/local /tmp/containerd-2.3.2-linux-amd64.tar.gz

# Download systemd service unit
sudo mkdir -p /usr/local/lib/systemd/system
sudo curl -L -o /usr/local/lib/systemd/system/containerd.service \
  https://raw.githubusercontent.com/containerd/containerd/main/containerd.service

sudo systemctl daemon-reload

# Generate default config
sudo mkdir -p /etc/containerd
sudo containerd config default > /etc/containerd/config.toml
```

Edit `/etc/containerd/config.toml` and set `SystemdCgroup` to `true` under the runc options:

```toml
[plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes.runc.options]
  SystemdCgroup = true
```

Note: Only this field needs to be changed. The rest of the options can be left as default.

```bash
# Enable and verify
sudo systemctl enable --now containerd
sudo systemctl restart containerd
grep SystemdCgroup /etc/containerd/config.toml
```
#### Step 2: Install runc

```bash
# Download (v1.4.3 is selected since this is the version tested against containerd v2.3.2's CI)
curl -L -o runc.amd64 https://github.com/opencontainers/runc/releases/download/v1.4.3/runc.amd64

# Install
sudo install -m 755 runc.amd64 /usr/local/sbin/runc
```
#### Step 3: Install CNI plugins

```bash
# Download (check latest version on releases page)
curl -L -o cni-plugins-linux-amd64-v1.9.1.tgz https://github.com/containernetworking/plugins/releases/download/v1.9.1/cni-plugins-linux-amd64-v1.9.1.tgz

# Extract to /opt/cni/bin
sudo mkdir -p /opt/cni/bin
sudo tar Cxzvf /opt/cni/bin cni-plugins-linux-amd64-v1.9.1.tgz
```
NOTE: v1.9.1 is in containerd's go.mod file.
#### Verify

```bash
# containerd running
sudo systemctl status containerd

# runc installed
runc --version

# CNI plugins present
ls /opt/cni/bin
```

### 8. Firewall

The default firewall that comes with ubuntu 24.04 is UFW

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 2222/tcp  
sudo ufw enable
```

### 9. Unattended Security Updates

```bash
sudo apt install unattended-upgrades -y
sudo dpkg-reconfigure unattended-upgrades
```

### 10. Audit Logging

```bash
# Verify auditd is running
sudo systemctl status auditd

#If not install auditd
sudo apt install auditd -y
sudo systemctl enable auditd
```

### 11. Cleanup and Seal Template

```bash
# Remove unnecessary packages
sudo apt autoremove -y
sudo apt clean

# Clear logs
sudo truncate -s 0 /var/log/*.log
sudo find /var/log -type f -name "*.log" -exec truncate -s 0 {} \;


# Clear machine-id (each clone generates its own)
sudo truncate -s 0 /etc/machine-id

# Clear SSH host keys (regenerated post-clone)
sudo rm /etc/ssh/ssh_host_*

# Clear current user history
history -c
history -w

# Clear history files
truncate -s 0 ~/.bash_history
sudo truncate -s 0 /root/.bash_history

# Shutdown the server
sudo systemctl poweroff 

```
---

## Part 2: Kubernetes Prerequisites (Each Cloned Node)

When cloning the template make sure that each node is a **full clone** not a linked clone as linked clone share virtual disk with the parent VM.

Run the following on **each node** after cloning from the template.

### 1. Post-Clone Setup

```bash
# Set hostname
sudo hostnamectl set-hostname <excalibur|mag|volt>
```

### 2. Static IP Assignment

```bash
sudo vi /etc/netplan/50-cloud-init.yaml
```

```yaml
network:
  version: 2
  ethernets:
    ens33:
      dhcp4: false
      addresses: [192.168.160.15X/24]  # change the X per node
      routes:
        - to: default
          via: 192.168.160.2 # check using ip route show
      nameservers:
        addresses: [8.8.8.8, 1.1.1.1]
```

```bash
sudo netplan apply
sudo reboot
```

NOTE: Use `.150` for Excalibur, `.151` for Mag, `.152` for Volt. Gateway is `192.168.160.2` (VMware NAT host).

### 3. Regenerate SSH Keys

```bash
# Regenerate the keys
sudo ssh-keygen -A
```
NOTE: If SSH is not running properly. See [challenges.md](challenges.md#2-ssh-resulted-to-failed-status-after-cloning)

### 4. Install kubeadm, kubelet, kubectl

These instructions are for Kubernetes v1.36.

**Update the apt package index** and install packages needed to use the Kubernetes apt repository:

```bash
sudo apt-get update
# apt-transport-https may be a dummy package; if so, you can skip that package
sudo apt-get install -y apt-transport-https ca-certificates curl gpg
```

**Download the public signing key** for the Kubernetes package repositories. The same signing key is used for all repositories so you can disregard the version in the URL:

```bash
# If the directory `/etc/apt/keyrings` does not exist, it should be created before the curl command, read the note below.
# sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.36/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
```

> **Note:** In releases older than Debian 12 and Ubuntu 22.04, directory `/etc/apt/keyrings` does not exist by default, and it should be created before the curl command.

**Add the appropriate Kubernetes apt repository.** Please note that this repository has packages only for Kubernetes 1.36; for other Kubernetes minor versions, you need to change the minor version in the URL to match your desired version (you should also check that you are reading the documentation for the version of Kubernetes that you plan to install).

```bash
# This overwrites any existing configuration in /etc/apt/sources.list.d/kubernetes.list
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.36/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
```

**Update the apt package index**, install kubelet, kubeadm and kubectl, and pin their version:

```bash
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
```

---

## Verification

Before proceeding to [01 - kubeadm init](01-kubeadm-init.md), confirm on all 3 nodes:

- [ ] Static IPs assigned and all 3 nodes reachable via ping from each other
- [ ] Hostnames set correctly (`hostname` command returns correct name)
- [ ] `/etc/hosts` has all 3 node entries
- [ ] Swap disabled (`free -h` shows 0 swap)
- [ ] containerd running (`systemctl status containerd`)
- [ ] kubeadm, kubelet, kubectl installed (`kubeadm version`)

---
[← Back to index](index.md)