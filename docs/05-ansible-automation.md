# Ansible Automation 

## Overview

After terraform provisioning. I still needed to configure the servers for it to have the needed packages and kubernetes versions. Doing this manually is time consuming and inefficient. I decided to opt for ansible considering it has an easier learning curve compared to chef/puppet.

## Inventory Structure

Ansible inventory was created using terraform's local file provider. This way I will not need to alter the file after every provisioning. 

```yaml
tenno_cluster:
  children:
    controllers:
      hosts:
        lotus:
          ansible_host: 10.9.8.50
    workers:
      hosts:
        excalibur-prime:
          ansible_host: 10.9.8.51
        mag-prime:
          ansible_host: 10.9.8.52
        volt-prime:
          ansible_host: 10.9.8.53
    bastion:
      hosts:
        ordis:
          ansible_host: 10.9.8.54
    storage:
      hosts:
        leverian:
          ansible_host: 10.9.8.55
  vars:
    ansible_ssh_private_key_file: /home/capistranoja/.ssh/januskey
    ansible_user: ubuntu  
```

## Roles

Initially, I was considering using one big playbook but I found that it will not meet my needs since I will have to configure controllers and workers differently. Upon checking I learned that roles exists. For the main cluster and initial bootstrap, there are 3 roles, cluster_wide, controllers, and workers. Below is the tree that shows the folder heirarchy.

```
│   └── roles
│       ├── cluster_wide
│       │   ├── handlers
│       │   │   └── main.yaml
│       │   ├── tasks
│       │   │   └── main.yaml
│       │   ├── templates
│       │   │   └── hosts.j2
│       │   └── vars
│       │       └── main.yaml
│       ├── controllers
│       │   ├── tasks
│       │   │   └── main.yaml
│       │   ├── templates
│       │   │   └── kubeadm-config.yaml.j2
│       │   └── vars
│       │       └── main.yaml
│       └── workers
│           ├── tasks
│           │   └── main.yaml
│           └── vars
│               └── main.yaml
```

## Playbook Structure

For playbook, the run sequence is cluster_wide, then controllers, and lastly workers. They are in playbook.yaml which runs role based tasks.

```yaml
- name: Node Preparation (All nodes)
  hosts: tenno_cluster
  become: true

  roles:
    - cluster_wide
    
- name: Controller Preparation
  hosts: controllers
  become: true

  roles:
    - controllers

- name: Worker Preparation
  hosts: workers
  become: true

  roles:
    - workers
```
| Role | Tasks |
| --- | --- |
| cluster_wide | This configures everything that both workers and controller needs. e.g common firewall rules, common packages
| controllers | This prepares the controller node, this includes installation of kubernetes and CNI bootstrap |
| workers | This will join the workers, configure worker specific firewall ports and rules, etc |


## Key Design Decisions

I went with roles instead of one big playbook once it became clear controllers and workers needed different configuration entirely, not just different variables. Cramming both into a single playbook with a bunch of when conditionals would've worked, but it gets harder to read and maintain as the cluster grows, especially if I add more node types later (like a dedicated storage role for leverian).

Splitting into cluster_wide, controllers, and workers also mirrors how the actual bootstrap process works: everything gets the same base prep first, then each node type branches into its own setup. This made the playbook run order (cluster_wide, then controllers, then workers) a direct reflection of the real dependency chain, since workers can't join a control plane that isn't bootstrapped yet.

Using Terraform's local file provider to generate the inventory was the other big one. Manually maintaining a static inventory file meant every time I destroyed and reprovisioned the cluster (which happened a lot early on), I'd have to go update IPs by hand. Generating it straight from Terraform state means the inventory is always accurate to whatever's actually running, no manual sync step.

CNI bootstrap also went into the controllers role instead of being a separate manual step after kubeadm init. Doing it manually meant remembering to apply the CNI manifest right after cluster init every single time I rebuilt the cluster, and it was easy to forget or apply the wrong version by hand. Folding it into Ansible meant control plane bootstrap and CNI install happen as one consistent, repeatable sequence, no post-init step to remember or get wrong.

## Testing / Validation

## Execution Steps

## Verification