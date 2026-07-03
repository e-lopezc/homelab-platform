#!/usr/bin/env bash
#
# Create the Ubuntu 24.04 cloud-init template that Terraform clones from.
# Run ONCE on the Proxmox host as root. Idempotent: re-run with FORCE=1 to rebuild.
#
#   ./create-ubuntu-template.sh
#   FORCE=1 VMID=9000 STORAGE=local-lvm ./create-ubuntu-template.sh
#
# Defaults match infra/terraform/terraform.tfvars (VMID 9000, local-lvm, vmbr0).
set -euo pipefail

# ── Config (override via env) ───────────────────────────────
VMID="${VMID:-9000}"
NAME="${NAME:-ubuntu-2404-cloudinit}"
STORAGE="${STORAGE:-local-lvm}"
BRIDGE="${BRIDGE:-vmbr0}"
IMG_URL="${IMG_URL:-https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img}"
IMG_DIR="${IMG_DIR:-/var/lib/vz/template/cloud-images}"
INSTALL_AGENT="${INSTALL_AGENT:-1}"   # bake qemu-guest-agent into the image
FORCE="${FORCE:-0}"                   # 1 = destroy + rebuild if VMID exists

IMG_PATH="${IMG_DIR}/$(basename "$IMG_URL")"

# ── Preflight ───────────────────────────────────────────────
[[ $EUID -eq 0 ]]          || { echo "ERROR: run as root on the Proxmox host." >&2; exit 1; }
command -v qm >/dev/null   || { echo "ERROR: 'qm' not found — not a Proxmox host?" >&2; exit 1; }

if qm status "$VMID" &>/dev/null; then
  if [[ "$FORCE" == "1" ]]; then
    echo "==> VMID $VMID exists — destroying (FORCE=1)"
    qm destroy "$VMID" --purge
  else
    echo "VMID $VMID already exists. Nothing to do (set FORCE=1 to rebuild)."
    exit 0
  fi
fi

# ── Fetch the cloud image ───────────────────────────────────
mkdir -p "$IMG_DIR"
if [[ -f "$IMG_PATH" ]]; then
  echo "==> Reusing cached image: $IMG_PATH"
else
  echo "==> Downloading $IMG_URL"
  wget -q --show-progress -O "$IMG_PATH" "$IMG_URL"
fi

# ── (optional) bake in the guest agent ──────────────────────
if [[ "$INSTALL_AGENT" == "1" ]]; then
  if command -v virt-customize >/dev/null; then
    echo "==> Installing qemu-guest-agent into the image"
    virt-customize -a "$IMG_PATH" --install qemu-guest-agent
  else
    echo "WARN: virt-customize not found (apt install libguestfs-tools) — skipping agent bake-in" >&2
  fi
fi

# ── Build the template VM ───────────────────────────────────
echo "==> Creating VM $VMID ($NAME)"
qm create "$VMID" --name "$NAME" --memory 2048 --cores 2 \
  --net0 "virtio,bridge=${BRIDGE}" --scsihw virtio-scsi-pci

echo "==> Importing disk to $STORAGE"
qm importdisk "$VMID" "$IMG_PATH" "$STORAGE"
# importdisk attaches the new disk as 'unusedN' — grab it and make it scsi0
DISK="$(qm config "$VMID" | awk -F': ' '/^unused0:/ {print $2; exit}')"
[[ -n "$DISK" ]] || { echo "ERROR: could not find imported disk on VM $VMID" >&2; exit 1; }

qm set "$VMID" --scsi0 "$DISK"
qm set "$VMID" --ide2 "${STORAGE}:cloudinit"        # cloud-init drive
qm set "$VMID" --boot "order=scsi0"
qm set "$VMID" --serial0 socket --vga serial0       # cloud images need a serial console
qm set "$VMID" --agent enabled=1

echo "==> Converting to template"
qm template "$VMID"

echo "✓ Template $VMID ($NAME) ready. Terraform can now clone it (vm_template_id = $VMID)."
echo "  Next:  cd infra/terraform && terraform plan"
