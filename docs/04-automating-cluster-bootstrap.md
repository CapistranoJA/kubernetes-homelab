# Automating Cluster Bootstrap

## Pain points of previous setup

Before I start, the OS hosting the vms have been migrated from Windows to Fedora. 

Provisioning the vms in this project manually meant creating each VM by hand through vmware then SSHing into every node one by one to set up networking, hostnames, and base packages. This didn't scale once the cluster grew past a couple of nodes, and it wasn't reproducible either, if a node broke and needed to be rebuilt, there was no record of how it was actually configured the first time around. Any drift between nodes had to be caught manually instead of just not happening in the first place.

## Provider Setup

The current cluster is provisioned using `dmacvicar/libvirt` Terraform provider against a local QEMU/KVM hypervisor on Fedora.

```hcl
terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.9.8"
    }
  }
}
```

## Defining the VM Resources

`libvirt_network` resource is reused sinced it is being managed separately by a different Terraform project.

Each node is defined as a `libvirt_domain` backed by a `libvirt_volume` cloned from a base cloud image.

All nodes are defined through a single `var.k8s_nodes` map instead of one resource block per VM, so adding or removing a node is just a variable change, not new HCL. A `libvirt_pool` holds all the volumes, and `libvirt_volume` uses `for_each` to create one disk per node, cloned straight from the Ubuntu cloud image URL.

```hcl
resource "libvirt_pool" "k8s_pool" {
  name = var.k8s_pool_name
  type = "dir"
  target = {
    path = var.k8s_pool_path
  }
}

resource "libvirt_volume" "k8s_volume" {
  for_each = var.k8s_nodes

  name     = "k8s-volume-${each.key}.qcow2"
  pool     = libvirt_pool.k8s_pool.name
  capacity = each.value.disk

  target = {
    format = {
      type = "qcow2"
    }
  }
  create = {
    content = {
      url = var.k8s_ubuntu_image_url
    }
  }
}
```


The vms is then built the same way, `for_each` over `k8s_nodes`, pulling memory, vcpu, disk, and cloud-init ISO per node key.

```hcl
resource "libvirt_domain" "k8s_domain" {
  for_each = var.k8s_nodes

  name        = each.key
  memory      = each.value.memory
  memory_unit = "MiB"
  vcpu        = each.value.cpu
  type        = "kvm"

  os = {
    type         = "hvm"
    type_arch    = "x86_64"
    type_machine = "q35"
  }
  features = {
    acpi = true
  }
  autostart = true
  devices = {
    disks = [
      {
        source = {
          volume = {
            pool   = libvirt_pool.k8s_pool.name
            volume = libvirt_volume.k8s_volume[each.key].name
          }
        }
        target = {
          dev = "vda"
          bus = "virtio"
        }
        driver = {
          type = "qcow2"
        }
      },
      {
        device = "cdrom"
        source = {
          volume = {
            pool   = libvirt_pool.k8s_pool.name
            volume = libvirt_volume.k8s_cloudinit_iso[each.key].name
          }
        }
        target = {
          dev = "sda"
          bus = "sata"
        }
      }
    ]
    interfaces = [
      {
        source = {
          network = {
            network = var.k8s_network_name
          }
        }
        model = {
          type = "virtio"
        }
        type = "network"
      }
    ]
    graphics = [
      {
        vnc = {
          auto_port = true
          listen    = "127.0.0.1"
        }
      }
    ]
    consoles = [{
      target = {
        type = "serial"
      }
    }]
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
  }
}
```

Each node also gets a QEMU guest agent channel wired in, which is what makes `terraform destroy` and IP lookups reliable later instead of guessing from DHCP leases.


## Cloud-Init Integration

## End-to-End Provisioning Flow

## Verification