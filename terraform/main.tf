provider "libvirt" {
  uri = var.libvirt_uri
}

resource "libvirt_pool" "k8s_pool" {
  name = var.k8s_pool_name
  type = "dir"
  target = {
    path = var.k8s_pool_path
  }
}

resource "libvirt_volume" "k8s_volume" {
  for_each = var.k8s_nodes

  name = "k8s-volume-${each.key}.qcow2"
  pool = libvirt_pool.k8s_pool.name
  capacity = each.value.disk

  target = {
    format = {
      type = "qcow2"
    }
  }
  create ={
    content = {
        url = var.k8s_ubuntu_image_url
    }
  }
}

resource "libvirt_cloudinit_disk" "k8s_cloudinit"{
    for_each = var.k8s_nodes
    name = "k8s-cloudinit-${each.key}"
    user_data = templatefile("${path.module}/cloud-init/user-data.tftpl", {
        hostname = each.key
    })
    meta_data = yamlencode({
        instance_id = each.key
        local_hostname = each.key
    })
}

resource "libvirt_domain" "k8s_domain" {
  for_each = var.k8s_nodes

  name = each.key
  memory = each.value.memory
  memory_unit = "MiB"
  vcpu = each.value.cpu
  type = "kvm"

  cpu = {
    mode = "host-passthrough"
  }

  os = {
    type = "hvm"
    type_arch = "x86_64"
    type_machine = "q35"
  }
  
  devices = {
    disks = [
      {
        source = {
            volume ={
                pool = libvirt_pool.k8s_pool.name
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
        vnc ={
            autoport = true
            listen = "127.0.0.1"
        }
      }
    ]
    
  }

}

