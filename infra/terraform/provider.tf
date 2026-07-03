# Connection to the Proxmox VE API.
#
# The API token is the one secret here. It is supplied via the environment
# (PROXMOX_VE_API_TOKEN) and is never written to a file or committed:
#   export PROXMOX_VE_API_TOKEN='user@pam!terraform=xxxxxxxx-xxxx-...'
provider "proxmox" {
  endpoint = var.proxmox_endpoint # e.g. https://pve.lan:8006/
  insecure = var.proxmox_insecure # true while trusting Proxmox's self-signed LAN cert

  # bpg/proxmox uses SSH for a few operations (e.g. uploading cloud-init snippets).
  ssh {
    agent    = true
    username = var.proxmox_ssh_username
  }
}
