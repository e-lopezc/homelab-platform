# Proxmox API User for Terraform

Least-privilege Proxmox VE identity used by Terraform
([`bpg/proxmox`](https://registry.terraform.io/providers/bpg/proxmox/latest/docs)) to
provision the k3s VMs. Pattern: **one user, one token, one custom role** — scoped to
create, update, *and* destroy VMs, nothing more. Part of **Phase 1 — Foundation**.

> Uses the **`@pve`** realm (not `@pam`). The user, ACL, and token id must all use
> the same realm or the grant won't apply to the identity Terraform authenticates as.

## Setup (run on the Proxmox host as root)

```bash
# 1. Dedicated automation user
pveum user add apiuser@pve --comment "Terraform automation (bpg/proxmox)"

# 2. API token — the secret is printed ONCE here; capture it now
pveum user token add apiuser@pve automation

# 3. Disable priv-separation so the token inherits the user's rights
pveum user token modify apiuser@pve automation --privsep 0

# 4. Least-privilege role for the full lifecycle
pveum role add AutomationRole -privs "\
VM.Allocate VM.Audit VM.Clone VM.PowerMgmt VM.GuestAgent.Audit \
VM.Config.CDROM VM.Config.Cloudinit VM.Config.CPU VM.Config.Disk \
VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options \
Datastore.Allocate Datastore.AllocateSpace Datastore.Audit \
SDN.Use Sys.Audit Sys.Console"

# 5. Grant at cluster root (propagates to all nodes/storage/VMs)
pveum aclmod / -user apiuser@pve -role AutomationRole

# 6. Verify — should list every priv above, each marked (*)
pveum user permissions apiuser@pve --path /
```

## Why the privileges

- **`VM.Allocate`** covers create **and destroy** — Proxmox has no separate delete
  privilege, so this one role does `terraform destroy` too.
- **`Datastore.AllocateSpace`** allocates *and frees* disk; **`Datastore.Allocate`**
  manages cloud-init snippet files.
- **`VM.Config.Cloudinit` / `CDROM`** — cloud-init injects SSH keys + static IP and
  attaches as a CD-ROM drive.
- **`VM.GuestAgent.Audit`** — lets the provider read each VM's IP back through the
  guest agent during `apply` (with `agent { enabled = true }`). PVE 8.3+/9.x
  replacement for the old `VM.Monitor`. Without it, `apply` errors on the IP read-back.
- **`SDN.Use`** — bridge assignment on **PVE 8.1+**.

The set is narrower than built-in `PVEVMAdmin` + `PVEDatastoreUser`.

## Gotchas

- **Priv-separation** (`privsep: 1`, the default on new tokens) makes a token
  powerless — effective rights are the *intersection* of user and token ACLs. We
  set `--privsep 0`. Stricter alternative: keep it on and also
  `aclmod ... -token 'apiuser@pve!automation'`.
- **`VM.Monitor` doesn't exist on PVE 8.3+/9.x** — it was split into granular
  `VM.GuestAgent.*` privileges, so `pveum` rejects it as invalid. Use
  **`VM.GuestAgent.Audit`** instead (already in the list above) — the provider needs
  it for the guest-agent IP read-back during `apply`. If the role already exists, add
  it in place: `pveum role modify AutomationRole -privs "VM.GuestAgent.Audit" -append 1`.
- The privilege validator reports only the *first* bad name and rejects the whole
  command atomically. On **PVE < 8.1**, `SDN.Use` fails next — drop it (bridge
  assignment still works via `VM.Config.Network`).

## Use in Terraform

```bash
export PROXMOX_VE_API_TOKEN='apiuser@pve!automation=<the-secret-uuid>'
cd infra/terraform && terraform init && terraform plan
```

`plan` reading state with no `401`/`403` confirms the chain. Keep the secret in env
or OpenBao — never in `*.tfvars` or Git.

## Rotate / revoke

```bash
pveum user token remove apiuser@pve automation        # then re-add + --privsep 0
pveum role modify AutomationRole -privs "<list>"       # adjust privileges in place
pveum aclmod / -user apiuser@pve -role AutomationRole -delete   # revoke grant
```
