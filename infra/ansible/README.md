# Ansible — k3s bootstrap

Installs k3s on the VMs Terraform provisioned: one **server** (control plane) + two
**agents**, then merges a `homelab` context into your `~/.kube/config`. Second half of
**Phase 1 — Foundation**.

## Prerequisites

- `ansible` and `kubectl` installed locally: `brew install ansible kubectl`
- SSH access as `ubuntu` to the nodes (cloud-init already installed your key).
- `inventory.ini` with real node IPs — gitignored, already set for this lab. On a fresh
  clone, copy `inventory.ini.example` and fill in.

## Run

```bash
cd infra/ansible
ansible all -m ping            # reachability check
ansible-playbook site.yml      # install server + agents, merge kubeconfig
```

## Verify

```bash
kubectl config use-context homelab
kubectl get nodes -o wide      # 3 Ready: 1 control-plane + 2 workers
kubectl get pods -A            # coredns, traefik, metrics-server, local-path Running
```

## Notes

- **k3s version** is pinned in `group_vars/all.yml` — verify it against the current
  stable release before a fresh install.
- **Idempotent** — re-running is a no-op (installs guarded by `creates:`).
- Keeps k3s's bundled **Traefik + servicelb**; these get formalized via GitOps (Phase 2).
- The fetched `homelab.kubeconfig` is gitignored; a timestamped `~/.kube/config.bak.*`
  is written before the merge.
