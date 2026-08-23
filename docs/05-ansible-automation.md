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

## Testing / Validation

## Execution Steps

## Verification