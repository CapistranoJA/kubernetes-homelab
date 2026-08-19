# KUBERNETES CLUSTER HOME LAB

A Kubernetes home lab built to learn the full lifecycle of running a cluster: infrastructure, networking, security, GitOps, and troubleshooting.

This project is intentionally built incrementally. Some parts are polished, some parts are still being rebuilt, and the mistakes are part of the documentation.

## Overview
This repo tracks a self-hosted, QEMU/KVM Kubernetes cluster built to simulate a real internal developer platform. The goal isn't a finished product, it's to practice the full lifecycle of standing up, securing, and operating a K8s platform and documented as I go.

## Current Status

- VMs have been configured using Ansible.
- Kubernetes have been installed and bootstrapped using ansible.
- Next will be Redeploying ArgoCD. Adding a bastion server, and a Storage Server(not part of the cluster, to prevent hostpath from being utilized when using App CSI)

## Architecture

Current:
<img width="462" height="532" alt="Tenno-cluster drawio" src="https://github.com/user-attachments/assets/b5d70eb1-a62b-4f38-bd90-433c353e3a9b" />

Target:


## Network
![Static Badge](https://img.shields.io/badge/Status-In--Progress-yellow)

A libvirt NAT network was chosen over a bridged interface to keep the lab isolated from the home network. This avoids any risk of colliding with the home router's DHCP range, and the host already has a working interface on this subnet.

| Range | Description | 
|---|---|
| 10.9.8.1 | Libvirt-homelab-nat Gateway  |
| 10.9.8.50 - 10.9.8.53 | Node Static IPs |
| 10.244.0.0/16 | Pod CIDR |
| TBD | Metal LB IP Pool |
| TBD | Bastion Host |
| TBD | External Storage |


## Tech Stack
![Static Badge](https://img.shields.io/badge/Status-In--Progress-yellow)

| Component | Tool | Why |
|---|---|---|
| Orchestration | Vanilla K8S(KUBEADM) | To better understand how Kubernetes works under the hood |
| GitOps | ArgoCD | Its either this or flux. I opted for ArgoCD since it seems that the UI is more rich compared to flux |
| IaC | Terraform | Its now or never. Treating infra as code made things easier to reproduce |
| Configuration & Bootstrap | Ansible | Easier to pick up than Chef/Puppet, and doesn't need an agent running on each node. |

## Repository Structure

| Directory | Description |
|---|---|
| `terraform/` | Libvirt infrastructure and cloud-init configuration |
| `cluster/` | Cluster-level configuration |
| `apps/` | Argo CD applications and Helm values |
| `app-bootstrap/` | Root Argo CD application |
| `docs/` | Setup notes, decisions, and troubleshooting |
| `ansible/` | Inventory, Playbooks, and Roles for node configurations |

## Setup
![Static Badge](https://img.shields.io/badge/Status-In--Progress-yellow)
The setup documentation is split into stages:

1. [Prerequisites](docs/00-prerequisites.md)
2. [kubeadm initialization](docs/01-kubeadm-init.md)
3. [Argo CD](docs/02-argocd.md)
4. [App-of-Apps](docs/03-app-of-apps.md)
5. [Automating cluster bootstrap](docs/04-automating-cluster-bootstrap.md)
6. [Ansible Automation](docs/05-ansible-automation.md)



## Challenges and Troubleshooting
![Static Badge](https://img.shields.io/badge/Status-In--Progress-yellow)

Most of the useful lessons from this project came from things breaking.

I have documented issues involving:

- SSH after cloning VMs
- cloud-init configuration
- UFW and Kubernetes forwarding
- Calico VXLAN and Typha connectivity
- Argo CD multi-source Helm values
- libvirt NAT networking
- QEMU Guest Agent configuration
- Ansible Idempotency
- Ansible SSH Issues
- Terraform provisioned nodes CPU Architecture

See [Challenges and Troubleshooting](docs/challenges.md).
