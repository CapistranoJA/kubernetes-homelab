k8s_nodes = {

  lotus = {
    memory = 4096
    cpu = 4
    disk = 61440
  }

  excalibur-prime = {
    memory = 6144
    cpu = 4
    disk = 61440
  }

  mag-prime = {
    memory = 6144
    cpu = 4
    disk = 61440
  }

  volt-prime = {
    memory = 6144
    cpu = 4
    disk = 61440
  }
}

k8s_ubuntu_image_url = "https://cloud-images.ubuntu.com/resolute/current/resolute-server-cloudimg-amd64.img"

ssh_authorized_keys = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAOPY6D4v5DtTAICwB/BwvFYCitPEaVTM26voer24vFF Void Key"