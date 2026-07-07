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
```w
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