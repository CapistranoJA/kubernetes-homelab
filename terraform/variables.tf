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
  default     = "/data/lib/libvirt/images/kubernetes"
}

variable "k8s_nodes" {
  description = "Nodes definition"
  type = map(object({
    memory = number
    cpu    = number
    disk   = number
    ip     = string
    role   = string
  }))
}

variable "k8s_network_name" {
  description = "Kubernetes cluster network name"
  type        = string
  default     = "libvirt-homelab-nat"
}

variable "k8s_ubuntu_image_url" {
  description = "Ubuntu cloud image URL"
  type        = string
}

variable "ssh_authorized_keys" {
  description = "List of SSH public keys for authorized access"
  type        = string
}

variable "ansible_inventory" {
  description = "Ansible Inventory Output"
  type        = string
  default     = "inventory.yaml"
}

variable "ansible_priv_key" {
  description = "Ansible priv key for ssh"
  type = string
}