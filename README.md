# KUBERNETES CLUSTER HOME LAB

A Kubernetes home lab built to learn the full lifecycle of running a cluster: infrastructure, networking, security, GitOps, and troubleshooting.

This project is intentionally built incrementally. Some parts are polished, some parts are still being rebuilt, and the mistakes are part of the documentation.

## Overview
This repo tracks a self-hosted, QEMU/KVM Kubernetes cluster built to simulate a real internal developer platform. The goal isn't a finished product, it's to practice the full lifecycle of standing up, securing, and operating a K8s platform and documented as I go.

## Current Status

- Terraform can provision the Kubernetes VMs
- Cloud-init configures the initial VM setup
- Kubernetes is bootstrapped with kubeadm
- Calico is installed as the cluster CNI
- Argo CD is running
- The App-of-Apps pattern is being used to manage applications
- The infrastructure is currently being rebuilt and improved with Terraform


## Architecture
TBD.


## Network
![Static Badge](https://img.shields.io/badge/Status-In--Progress-yellow)

VMnet8 (NAT) was chosen over Bridged networking to keep the lab isolated from the home network to avoid any risks of colliding with the home router's DHCP range, and the host already has a working interface on this subnet.

| Range | Description | 
|---|---|
| 10.9.8.1/24 | Libvirt-homelab-nat Gateway  |
| TBD | Node Static IPs |
| 10.244.0.0/16 | Pod CIDR |
| TBD | Metal LB IP Pool |


## Tech Stack
![Static Badge](https://img.shields.io/badge/Status-In--Progress-yellow)

| Component | Tool | Why |
|---|---|---|
| Orchestration | Vanilla K8S(KUBEADM) | To better understand how Kubernetes works under the hood |

## Repository Structure

| Directory | Description |
|---|---|
| `terraform/` | Libvirt infrastructure and cloud-init configuration |
| `cluster/` | Cluster-level configuration |
| `apps/` | Argo CD applications and Helm values |
| `app-bootstrap/` | Root Argo CD application |
| `docs/` | Setup notes, decisions, and troubleshooting |

## Setup
![Static Badge](https://img.shields.io/badge/Status-In--Progress-yellow)
The setup documentation is split into stages:

1. [Prerequisites](docs/00-prerequisites.md)
2. [kubeadm initialization](docs/01-kubeadm-init.md)
3. [Argo CD](docs/02-argocd.md)
4. [App-of-Apps](docs/03-app-of-apps.md)
5. [Automating cluster bootstrap](docs/04-automating-cluster-bootstrap.md)

Current Status: Terraform Documentation steps - in progress. I created the VMs and TF files first.


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

See [Challenges and Troubleshooting](docs/challenges.md).
