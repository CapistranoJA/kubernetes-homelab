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