# KUBERNETES CLUSTER HOME LAB
A Kubernetes home lab documenting my DevOps journey — built incrementally, mistakes and all.

## Overview
This repo tracks a self-hosted, bare-metal Kubernetes cluster built to simulate a real internal developer platform. The goal isn't a finished product, it's to practice the full lifecycle of standing up, securing, and operating a K8s platform and documented as I go.

## Architecture
<img width="421" height="481" alt="Architecture" src="https://github.com/user-attachments/assets/dbfdb4ca-0d1b-4631-aa7a-c9fc3310f418" />


## Network
![Static Badge](https://img.shields.io/badge/Status-In--Progress-yellow)

VMnet8 (NAT) was chosen over Bridged networking to keep the lab isolated from the home network to avoid any risks of colliding with the home router's DHCP range, and the host already has a working interface on this subnet.

| Range | Description | 
|---|---|
| 192.168.160.0/24 | VMware Network Adapter VMnet8 |
| 192.168.160.150-.152 | Node Static IPs |
| 192.168.160.20-.27 | Metal LB IP Pool |
| 192.168.160.1 | Reserved for Host OS that runs the VMs |

## Tech Stack
![Static Badge](https://img.shields.io/badge/Status-In--Progress-yellow)

| Component | Tool | Why |
|---|---|---|
| Orchestration | Vanilla K8S(KUBEADM) | To better understand how Kubernetes works under the hood |


## Key Decisions
![Static Badge](https://img.shields.io/badge/Status-In--Progress-yellow)

## Setup and Reproduction
![Static Badge](https://img.shields.io/badge/Status-In--Progress-yellow)

## Challenges and Troubleshooting
![Static Badge](https://img.shields.io/badge/Status-In--Progress-yellow)

## Status
![Static Badge](https://img.shields.io/badge/Status-In--Progress-yellow)

