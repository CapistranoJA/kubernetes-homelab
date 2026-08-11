output "vm_details" {
  description = "VM Name"
  value = {
    for vm, vms in var.k8s_nodes :
    vm => {
      name = vm
      ip   = vms.ip
    }
  }
}