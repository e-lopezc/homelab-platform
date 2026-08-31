# Phase 3 — cert-manager + internal CA + Traefik (walkthrough)

> Concise record of what Phase 3 set up and **where to change each part**. LAN-only TLS.
> Public exposure (Cloudflare Tunnel + Let's Encrypt) is deliberately deferred to Phase 5.

Everything below is applied by **Flux** from Git, in dependency order
(`platform-controllers → platform-configs → apps`). You don't `kubectl apply` any of it.

---

## 1. cert-manager — the certificate operator
**Files:** `platform/controllers/cert-manager/`
- `repository.yaml` — a `HelmRepository` pointing at `https://charts.jetstack.io`.
- `release.yaml` — a `HelmRelease` that installs cert-manager (**pinned `v1.21.0`**), with its
  CRDs (`crds.enabled: true`, `crds.keep: true`).
- `namespace.yaml` — the `cert-manager` namespace.

Installs the cert-manager controller, webhook, and cainjector. From here, asking for a TLS cert
is a declarative resource instead of manual `openssl`.
**To change:** cert-manager version → `release.yaml` (`version:`). Chart tuning → `release.yaml` (`values:`).

## 2. Internal CA — our private PKI
**Files:** `platform/configs/cert-manager/` (applied *after* step 1, because it needs cert-manager's CRDs)
- `selfsigned-issuer.yaml` — a `selfSigned` ClusterIssuer, used once to sign the root below.
- `root-ca.yaml` — a self-signed **root CA** `Certificate` (`isCA: true`, 10y), stored in the
  `homelab-root-ca` secret in the `cert-manager` namespace.
- `ca-issuer.yaml` — the `homelab-ca-issuer` ClusterIssuer that signs all service certs from that root.

Result: every service cert chains to one root CA. Trust that root once (step 5) → everything is green.
**To change:** CA validity/name/key → `root-ca.yaml`. Issuer name (referenced by ingresses) → `ca-issuer.yaml`.

## 3. Traefik — formalized under GitOps
**Files:** `platform/configs/traefik/helmchartconfig.yaml`
k3s still *installs* Traefik (v3.7.4); we now own its **config** in Git via a k3s `HelmChartConfig`.
Current override: redirect all HTTP (`web`) → HTTPS (`websecure`).
**To change:** any Traefik setting → `helmchartconfig.yaml` (`valuesContent:`). If a change no-ops,
check the values keys against the k3s traefik chart (`traefik-40.x`).

## 4. whoami demo — proof the chain works
**Files:** `apps/whoami/`
A tiny app + `Service` + `Ingress` on host `whoami.homelab`. The ingress annotation
`cert-manager.io/cluster-issuer: homelab-ca-issuer` makes cert-manager auto-issue a cert into the
`whoami-tls` secret, which Traefik serves.
**To change:** hostname → `ingress.yaml` (`host:` + `tls.hosts`). Remove the demo → delete `apps/whoami/`
and its entry in `apps/kustomization.yaml`.

## 5. Out-of-band steps (not in Git — done once, per machine)
- **Trust the CA** on your laptop:
  ```
  kubectl -n cert-manager get secret homelab-root-ca -o jsonpath='{.data.tls\.crt}' | base64 -d > homelab-ca.crt
  # macOS: Keychain Access → System → import homelab-ca.crt → set "Always Trust"
  # Linux (Debian/Ubuntu):
  sudo cp homelab-ca.crt /usr/local/share/ca-certificates/homelab-ca.crt
  sudo update-ca-certificates
  # Linux (Fedora/RHEL):
  sudo cp homelab-ca.crt /etc/pki/ca-trust/source/anchors/
  sudo update-ca-trust
  ```
- **Resolve the hostname** (no real DNS yet): add to `/etc/hosts`
  ```
  <any-node-ip>  whoami.homelab
  ```
  Any of the 3 node IPs works — Traefik's Ingress controller runs cluster-wide,
  so it answers on every node regardless of which one currently schedules the pod.

## 6. Verify
```
flux get kustomizations                              # all Ready
kubectl -n cert-manager get pods                     # controller, webhook, cainjector Running
kubectl get clusterissuer                            # selfsigned + homelab-ca-issuer Ready=True
kubectl -n whoami get certificate whoami-tls         # Ready=True; secret populated
```
Then open `https://whoami.homelab` → whoami page, valid padlock (cert chains to homelab CA);
plain `http://` redirects to `https://`.

**Status Ready doesn't always mean behavior is correct** — the redirect bug this phase fixed
was invisible to every `kubectl`/`flux` status check above; the values key was silently
accepted and ignored. Confirm the redirect actually happens:
```
curl -sI http://whoami.homelab/ | head -1   # expect: HTTP/1.1 308 Permanent Redirect
```

## 7. Known trade-off — the CA is rebuilt, not backed up
The root CA's private key exists only as the `homelab-root-ca` Kubernetes Secret, stored in
this single k3s server's SQLite datastore. There's no embedded-etcd HA (1 server + 2 agents)
and nothing exports the key outside the cluster. That means `terraform destroy` → rebuild
generates a **new** CA every time, invalidating every previously-trusted client cert — you'll
re-import `homelab-ca.crt` after any full rebuild. This is a conscious trade-off for a LAN-only
portfolio cluster, not an oversight: exporting/backing up the CA key is parked as future work,
not required for Phase 3 to be considered done.

---

### Where to change things (quick index)
| Want to change… | Edit |
|---|---|
| cert-manager version | `platform/controllers/cert-manager/release.yaml` |
| CA lifetime / name | `platform/configs/cert-manager/root-ca.yaml` |
| Signing issuer name | `platform/configs/cert-manager/ca-issuer.yaml` |
| Traefik behaviour (redirects, etc.) | `platform/configs/traefik/helmchartconfig.yaml` |
| Demo hostname / remove demo | `apps/whoami/ingress.yaml`, `apps/whoami/` |
