variable "libvirt_uri" {
  description = "Libvirt connection URI"
  type        = string
  default     = "qemu:///system"
}

variable "k8s_pool_name" {
  description = "Kubernetes cluster pool name"
  type        = string
  default     = "k8s-pool"
}

variable "k8s_pool_path" {
  description = "Path for the Kubernetes cluster pool"
  type        = string
  default     = "/data/lib/libvirt/images/kubernetes/"
}

variable "k8s_nodes" {
  description = "Nodes definition"
  type = map(object({
    memory = number
    cpu = number
    disk = number
  }))
}

variable "k8s_network_name" {
  description = "Kubernetes cluster network name"
  type        = string
  default     = "libvirt-homelab-nat"
}