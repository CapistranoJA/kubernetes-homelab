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

### 7. ArgoCD Application stuck on Unknown sync status due to invalid Helm value file path

* **Symptom:** The self-managed argocd Application remained stuck in Unknown sync status, and the Resources tab in the ArgoCD UI continuously displayed a loading spinner. The argocd-application-controller logs repeatedly showed:

  ```bash 
  level=warning msg="Ignoring temporary failed attempt to compare app state against repo" application=argocd error="failed to get repo objects"
  ```

also noticed compare_app_state_ms consistently taking over 20 seconds for this Application, while root application reconciled in well under a second. 

* **Cause:** The Application was using a single source: that pointed directly to the Argo Helm repository (`https://argoproj.github.io/argo-helm`), while helm.valueFiles referenced a relative path:

  ```yaml
  valueFiles:
    - ../values/argocd/argocd-values.yaml
  ```
The values file wasn't part of the Helm repository.It lived in the portfolio Git repository instead. Since Helm repositories only contain packaged charts, ArgoCD couldn't resolve a relative path outside of the repository root and failed with:

  ```
  error resolving value file path: file '../values/argocd/argocd-values.yaml' resolved to outside repository root
  ```

* **Resolution:** updated the Application to use ArgoCD's multi-source feature so the Helm chart could still be pulled from the Argo Helm repository while the values file was loaded from my Git repository:

  ```yaml
  spec:
    project: default
    sources:
      - chart: argo-cd
        repoURL: https://argoproj.github.io/argo-helm
        targetRevision: 10.2.2
        helm:
          releaseName: argocd
          valueFiles:
            - $values/apps/values/argocd/argocd-values.yaml
          ignoreMissingValueFiles: true
      - repoURL: https://github.com/CapistranoJA/kubernetes-homelab.git
        targetRevision: HEAD
        ref: values
  ```

The `ref: values` field exposes the Git repository as $values, allowing the Helm chart to reference files from that repository instead of trying to resolve them within the chart repository. After syncing the Application, it reconciled successfully and reached a Synced and Healthy state.

  Verify:

  ```bash
  kubectl get application argocd -n argocd -o yaml
  ```

  Expected:

  ```
  status:
    sync:
      status: Synced
    health:
      status: Healthy
  ```

  Confirm resources render correctly:

  ```bash
  kubectl get pods -n argocd
  ```

### 8. Libvirt NAT network had DHCP but no internet connectivity

* **Symptom:** Both my Ubuntu and Windows VMs were able to get an IP address from the libvirt network, but neither had internet access. My VMs received an IP and default route:

  ```text
  inet 10.9.8.155/24
  default via 10.9.8.1
  ```

  But both of these failed:

  ```bash
  ping -c 3 1.1.1.1
  ping -c 3 archive.ubuntu.com
  ```

  This also caused cloud-init to fail when trying to install `qemu-guest-agent`:

  ```text
  Failed to install the following packages: {'qemu-guest-agent'}
  ```

* **Cause:** I initially configured a custom NAT address range on the terraform practice project:

  ```hcl
  forward = {
    mode = "nat"

    nat = {
      addresses = [{
        start = cidrhost(var.network_cidr, 1)
        end   = cidrhost(var.network_cidr, 254)
      }]
    }
  }
  ```

  Upon checking, this caused libvirt to use addresses from my internal `10.9.8.0/24` network for SNAT. DHCP was still working, so my VMs could get an IP address and reach the gateway, but they could not reach anything outside the network.

  This was a little confusing at first because the network looked like it was working. My VMs had an IP address, a default gateway, and DNS resolution was also working. I initially thought the issue was with cloud-init or the guest itself.

* **Resolution:** I removed the custom `nat.addresses` configuration and let libvirt handle NAT automatically:

  ```hcl
  forward = {
    mode = "nat"
  }
  ```

  I then recreated the network and VM. After that, the VM was able to access the internet normally:

  ```bash
  ping -c 3 1.1.1.1
  ping -c 3 archive.ubuntu.com
  ```

  Cloud-init was then able to install `qemu-guest-agent`, and the guest agent connected successfully.

Verify:

```bash
systemctl status qemu-guest-agent
```

Expected:

```text
Active: active (running)
```

Then from the host:

```bash
sudo virsh domifaddr excalibur-prime --source agent
```

Returns the VM's IP address through the QEMU Guest Agent.

### 9. Explicitly setting QEMU Guest Agent channel mode caused a Terraform provider error

* **Symptom:** I added a QEMU Guest Agent channel to my `libvirt_domain` resource. When I explicitly set the Unix socket mode to `bind`:

  ```hcl
  channels = [
    {
      source = {
        unix = {
          mode = "bind"
        }
      }

      target = {
        virt_io = {
          name = "org.qemu.guest_agent.0"
        }
      }
    }
  ]
  ```

  Terraform plan showed no error, but applying it resulted in:

  ```text
  Error: Provider produced inconsistent result after apply

  .devices.channels[0].source.unix.mode: was
  cty.StringVal("bind"), but now null.
  ```

* **Cause:** I initially tried to explicitly set the Unix socket mode to `bind` after seeing `mode='bind'` in the generated libvirt XML. However, when I set:

  ```hcl
  unix = {
    mode = "bind"
  }
  ```

  Terraform failed with a provider state inconsistency after the domain was created:

  ```text
  .devices.channels[0].source.unix.mode: was
  cty.StringVal("bind"), but now null.
  ```

  Based on the error, the provider was not returning the configured `mode` value back to Terraform state after the apply. Since the empty `unix = {}` configuration created the working channel without triggering the error, explicitly setting `mode` was unnecessary in my case.


* **Resolution:** Based on this [solution](https://github.com/dmacvicar/terraform-provider-libvirt/discussions/1231#discussioncomment-15112011), I removed the explicit `mode = "bind"` configuration and left the Unix source empty:

  ```hcl
  channels = [
    {
      source = {
        unix = {}
      }

      target = {
        virt_io = {
          name = "org.qemu.guest_agent.0"
        }
      }
    }
  ]
  ```
Terraform was able to apply the domain without the result error.

Verify:

```bash
sudo virsh dumpxml <vm-name>
```

It is now:

```xml
    <channel type='unix'>
      <source mode='bind' path='/run/libvirt/qemu/channel/2-excalibur-prime/org.qemu.guest_agent.0'/>
      <target type='virtio' name='org.qemu.guest_agent.0' state='connected'/>
      <alias name='channel0'/>
      <address type='virtio-serial' controller='0' bus='0' port='1'/>
    </channel>
```
