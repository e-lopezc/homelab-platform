# ── Proxmox connection ──────────────────────────────────────
variable "proxmox_endpoint" {
  description = "Proxmox VE API URL, e.g. https://pve.lan:8006/"
  type        = string
}

variable "proxmox_insecure" {
  description = "Skip TLS verification (true for Proxmox's self-signed LAN cert)"
  type        = bool
  default     = true
}

variable "proxmox_ssh_username" {
  description = "SSH user on the Proxmox host (used by the provider for snippet uploads)"
  type        = string
  default     = "root"
}

variable "proxmox_node" {
  description = "Name of the Proxmox node that will host the VMs (e.g. 'pve')"
  type        = string
}

# ── Shared VM settings ──────────────────────────────────────
variable "vm_template_id" {
  description = "VMID of the Ubuntu 24.04 cloud-init template to clone"
  type        = number
}

variable "vm_datastore" {
  description = "Proxmox storage pool for VM disks (e.g. 'local-lvm')"
  type        = string
  default     = "local-lvm"
}

variable "vm_network_bridge" {
  description = "Proxmox bridge the VMs attach to (e.g. 'vmbr0')"
  type        = string
  default     = "vmbr0"
}

variable "vm_gateway" {
  description = "LAN default gateway for the VMs (e.g. '192.168.1.1')"
  type        = string
}

variable "ssh_public_keys" {
  description = "SSH public keys injected into each VM via cloud-init"
  type        = list(string)
}

# ── Cluster topology ────────────────────────────────────────
# One entry per node. `role` drives the k3s install (server vs agent), which
# Ansible consumes in a later step.
variable "nodes" {
  description = "k3s nodes to create"
  type = map(object({
    role   = string # "server" or "agent"
    vmid   = number
    cores  = number
    memory = number # MB
    disk   = number # GB
    ip     = string # CIDR, e.g. 192.168.1.21/24
  }))
}
