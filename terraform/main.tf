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
}