terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.9.8"
    }

    local = {
      source  = "hashicorp/local"
      version = "2.9.0"
    }
  }
}