# Phase 4 — Observability (walkthrough)

> Concise record of what Phase 4 sets up and **where to change each part**. In progress:
> kube-prometheus-stack and Grafana so far; Loki and OpenCost land in later sections.

Everything below is applied by **Flux** from Git. The exception is the out-of-band step,
which has to be done by hand before Flux reconciles.

---

## Out-of-band steps (not in Git — done once per cluster)

- **Grafana admin Secret**: create it *before* Flux reconciles the kube-prometheus-stack
  release. Without it Grafana cannot start, and the whole release rolls back, Prometheus
  included. The password is generated inline, so it never appears in shell history.
  External Secrets Operator replaces this step in Phase 5.
  ```
  kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
  kubectl -n monitoring create secret generic grafana-admin \
    --from-literal=admin-user=admin \
    --from-literal=admin-password="$(openssl rand -base64 24)"
  # Retrieve it for your password manager:
  kubectl -n monitoring get secret grafana-admin -o jsonpath='{.data.admin-password}' | base64 -d
  ```
  The first command creates `monitoring` if it doesn't exist yet. On a fresh rebuild, Flux
  may not have created it at this point.

  To rotate the password, update the Secret, then run
  `kubectl -n monitoring rollout restart deploy/kube-prometheus-stack-grafana`.
  The database is an emptyDir, so the new password applies on restart.

- **Resolve the hostname**: same as whoami, e.g. add to `/etc/hosts`
  ```
  <any-node-ip>  grafana.homelab
  ```
