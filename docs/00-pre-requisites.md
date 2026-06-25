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
