# Troubleshooting & Lessons Learned

## 00: Pre-Requisites
### 1. WSL ssh-copy-id Directory Failure
* **Symptom:** `mktemp: failed to create directory via ssh-copy-id`
* **Cause:** `~/.ssh` directory missing or incorrect permissions on the target
* **Resolution:**
```bash
  mkdir -p ~/.ssh && chmod 700 ~/.ssh
```

### 2. SSH resulted to failed status after cloning
* **Symptom:** `kex_exchange_identification: read: Connection reset by peer Connection reset by 192.168.160.150 port 2222`
* **Cause:** Missing privilege separation directory `/run/sshd` identified via `sudo sshd -t`
* **Resolution:**
```bash
  sudo mkdir -p /run/sshd
  sudo systemctl restart ssh
```

### 3. SSH Warning: Remote Host Identification Has Changed After Cloning and changing hostname
* **Symptom:**
```
  @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
  @    WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!     @
  @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
  Host key verification failed.
```
* **Cause:** Expected behavior — SSH host keys are regenerated on 
  first boot after cloning. The local `known_hosts` file still 
  has the old template's host key fingerprint for that IP.
* **Resolution:** Remove the stale entry from `known_hosts` and reconnect:
```bash
  # Run per node
  ssh-keygen -f '~/.ssh/known_hosts' -R '[192.168.160.15X]:2222'

  # Or clear all known_hosts entirely (safe for a fresh lab)
  > ~/.ssh/known_hosts
```
  Reconnect and type `yes` to accept the new host fingerprint. 

> **Note:** This is not a security incident — it is the expected 
> result of SSH host key regeneration by design. See 
> [Part 1 Step 11 - Cleanup and Seal Template](00-prerequisites.md#11-cleanup-and-seal-template)

### 4. PasswordAuthentication not taking effect after configuration

* **Symptom:** `sudo sshd -T | grep passwordauthentication` returns 
  `passwordauthentication yes` despite setting `PasswordAuthentication no` 
  in `/etc/ssh/sshd_config`
* **Cause:** `/etc/ssh/sshd_config.d/50-cloud-init.conf` contains 
  `PasswordAuthentication yes` which takes precedence over the main 
  `sshd_config` file. Ubuntu 24.04 cloud-init generates this override 
  file during installation.
* **Resolution:**
```bash
  sudo vi /etc/ssh/sshd_config.d/50-cloud-init.conf
  # Change: PasswordAuthentication yes → no

  sudo systemctl restart ssh

  # Verify
  sudo sshd -T | grep passwordauthentication
  # Expected: passwordauthentication no
```

### 5. Calico networking failure after full cluster restart

* **Symptom:** After restarting all cluster nodes, one `calico-node` pod remained
  `0/1 Ready` with repeated readiness probe failures:

  ```
  calico/node is not ready: BIRD is not ready:
  error querying BIRD: unable to connect to BIRDv4 socket:
  dial unix /var/run/calico/bird.ctl: connect: connection refused
  ```

  Any workload scheduled on the affected node was unable to reach the
  Kubernetes API Service (`10.96.0.1:443`). For example, Argo CD pods entered
  `CreateContainerConfigError` or `Init:Error`, with init container logs
  reporting:

  ```
  dial tcp 10.96.0.1:443: i/o timeout
  ```

  The Tigera `Installation` resource also reported:

  ```
  Ready: False
  Degraded: True
  Reason: PodFailure
  ```

* **Cause:** This cluster uses the Calico eBPF dataplane with
  `VXLANCrossSubnet` encapsulation, which requires UDP/4789 for VXLAN traffic.
  The Tigera Operator also deployed **Typha**, which communicates with
  `calico-node` over TCP/5473. These ports were not permitted through UFW,
  preventing Calico from fully initializing on the affected node. As a result,
  pod networking on that node never became operational, causing unrelated
  workloads to fail when accessing ClusterIP services such as the Kubernetes
  API.

* **Resolution:**

  ```bash
  # Run on every cluster node
  sudo ufw allow 4789/udp
  sudo ufw allow 5473/tcp
  ```

  After updating the firewall rules, verify that Calico recovers:

  ```bash
  kubectl get pods -n calico-system
  kubectl get installation default
  ```
  
### 6. Pod-to-Service communication blocked by UFW forwarding policy

* **Symptom:** Although all Calico components appeared healthy, workloads were
  unable to reach ClusterIP services. Argo CD pods remained in
  `CreateContainerConfigError` / `Init:Error`, with init containers reporting:

  ```
  dial tcp 10.96.0.1:443: i/o timeout
  ```

  Testing from within another running pod confirmed that neither the Kubernetes
  API Service (`10.96.0.1:443`) nor the API server endpoint
  (`192.168.160.150:6443`) was reachable.

* **Cause:** UFW's default forwarding policy was set to `DROP`
  (`deny (routed)`). Although the required Kubernetes and Calico ports were
  allowed, forwarded pod traffic was still blocked, preventing pods from
  communicating across the cluster.

* **Resolution:**

  ```bash
  # /etc/default/ufw
  DEFAULT_FORWARD_POLICY="ACCEPT"

  sudo ufw reload
  ```

  Verify:

  ```bash
  sudo ufw status verbose
  ```

  Expected:

  ```
  Default: deny (incoming), allow (outgoing), allow (routed)
  ```

  After reloading UFW, verify pod networking and affected workloads:

  ```bash
  kubectl get pods -n argocd
  kubectl get pods -n calico-system
  ```