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
ssh-copy-id -i ./keyname.pub devopsuser@<template-ip>

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

### 4. Static IP Assignment
We will bake the netplan template into the VM so that when we create clones we only have to change the last digit of the IP.

```bash
sudo vi /etc/netplan/50-cloud-init.yaml
```

```yaml
network:
  version: 2
  ethernets:
    ens33:
      dhcp4: false
      addresses: [192.168.160.15X/24]  # We bake the template IP. .15X instead of the actual value.
      routes:
        - to: default
          via: 192.168.160.2 # check using ip route show
      nameservers:
        addresses: [8.8.8.8, 1.1.1.1]
```
Save the file but do not apply.


### 5. Disable Swap

kubeadm requires swap to be disabled.

```bash
sudo swapoff -a

# Comment out swap entry in /etc/fstab to persist across reboot
sudo vi /etc/fstab
```



### 6. Firewall

The default firewall that comes with ubuntu 24.04 is UFW

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 2222/tcp  
sudo ufw enable
```

### 7. Unattended Security Updates

```bash
sudo apt install unattended-upgrades -y
sudo dpkg-reconfigure unattended-upgrades
```

### 8. Audit Logging

```bash
# Verify auditd is running
sudo systemctl status auditd

#If not install auditd
sudo apt install auditd -y
sudo systemctl enable auditd
```

### 9. Cleanup and Seal Template

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

### 3. /etc/hosts Entries

All 3 nodes need to resolve each other by hostname:

```bash
sudo vi /etc/hosts
```

```
192.168.160.150  excalibur
192.168.160.151  mag
192.168.160.152  volt
```

---

## Verification



---
[← Back to index](index.md)