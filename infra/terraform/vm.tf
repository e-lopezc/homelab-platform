# Turns the `nodes` map into real Proxmox VMs by cloning the Ubuntu 24.04
# cloud-init template (built once by scripts/create-ubuntu-template.sh) and
# personalizing each clone via cloud-init. This is the resource that exercises
# the AutomationRole privileges — clone, config, disk, network, cloud-init, power.
resource "proxmox_virtual_environment_vm" "node" {
  for_each = var.nodes

  node_name   = var.proxmox_node
  name        = each.key # e.g. "k3s-server-1"
  vm_id       = each.value.vmid
  description = "k3s ${each.value.role} — managed by Terraform"
  tags        = ["k3s", each.value.role]

  on_boot         = true # start with the Proxmox host
  stop_on_destroy = true # hard-stop on destroy so `terraform destroy` never hangs

  # Full clone = an independent disk, so destroying a node never touches the template.
  clone {
    vm_id = var.vm_template_id
    full  = true
  }

  # qemu-guest-agent is baked into the template; lets Proxmox coordinate shutdown.
  agent {
    enabled = true
  }

  cpu {
    cores = each.value.cores
    type  = "host" # pass through host CPU features
  }

  memory {
    dedicated = each.value.memory # MB
  }

  # Resize the cloned root disk up to the per-node size. cloud-init grows the
  # filesystem to fill it on first boot.
  disk {
    datastore_id = var.vm_datastore
    interface    = "scsi0"
    size         = each.value.disk # GB
  }

  network_device {
    bridge = var.vm_network_bridge
  }

  # Cloud-init: static IP + SSH keys, zero interactive setup.
  initialization {
    datastore_id = var.vm_datastore

    ip_config {
      ipv4 {
        address = each.value.ip # CIDR, e.g. 192.168.1.21/24
        gateway = var.vm_gateway
      }
    }

    user_account {
      username = "ubuntu" # default user in the Ubuntu cloud image
      keys     = var.ssh_public_keys
    }
  }
}
