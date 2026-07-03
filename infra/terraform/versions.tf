# Pin the toolchain so a rebuild far in the future resolves the same versions.
# bpg/proxmox is pre-1.0, so minor releases can carry breaking changes — that's
# exactly why we pin tightly and bump deliberately.
terraform {
  required_version = ">= 1.9"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.110.0" # patch bumps OK (0.110.x); minor bumps are deliberate (pre-1.0 = minors can break)
    }
  }
}
