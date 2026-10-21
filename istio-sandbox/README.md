# Istio sandbox

A local [kind](https://kind.sigs.k8s.io/) cluster running [Istio](https://istio.io/)
with three small FastAPI services that talk to each other through the mesh:

```
curl :8080 ──► istio-ingressgateway ──► frontend ──► orders ──► inventory v1 (90%)
                                                            └─► inventory v2 (10%)
```

Every pod gets an Envoy sidecar. Traffic between them is mutual-TLS only, and
authorization policies allow just the chain above.

| Path | What it is |
| --- | --- |
| `apps/` | Service code (`frontend`, `orders`, `inventory`) and one shared `Dockerfile` |
| `kind-config.yaml` | 1 control-plane + 2 workers, host port 8080 → gateway NodePort 30080 |
| `istio/` | `istioctl install` config (demo profile, NodePort gateway, Jaeger tracing) |
| `manifests/` | Namespace, apps, mTLS, authz, gateway, traffic rules |
| `scripts/` | `up.sh` / `down.sh` |

## Install the tools

Docker must already work without `sudo`. Then:

```bash
sudo pacman -S kind kubectl
```

`istioctl` is not needed up front: `up.sh` downloads the Istio release
(`ISTIO_VERSION`, default `1.31.2`) into `~/.local/opt/istio-<version>` on first run.
To call it yourself, link it onto your `PATH`:

```bash
ln -s ~/.local/opt/istio-1.31.2/bin/istioctl ~/.local/bin/istioctl
```

---

## Run it

```bash
./istio-sandbox/scripts/up.sh
```

The script is safe to re-run: it reuses the cluster, re-applies Istio and the
manifests, and rebuilds the images (so it is also how you deploy code changes).

Check every pod has two containers (app + `istio-proxy`):

```bash
kubectl get pods -n mesh-demo
```

Call the chain through the ingress gateway:

```bash
curl -s localhost:8080/ | python3 -m json.tool
```

Count the canary split:

```bash
for i in $(seq 50); do curl -s localhost:8080/ | grep -o '"version":"v."'; done | sort | uniq -c
```

Tear down:

```bash
./istio-sandbox/scripts/down.sh
```

---

## Things to try

### mTLS

`manifests/20-mtls.yaml` sets the namespace to `STRICT`. A pod outside the
mesh cannot talk to the services:

```bash
kubectl run plain --rm -it --restart=Never --image=curlimages/curl -- \
  curl -sv http://orders.mesh-demo:8000/orders
# connection reset: the sidecar rejects plaintext
```

### Authorization

`manifests/30-authz.yaml` denies everything, then allows
gateway → frontend → orders → inventory by service-account identity. Skipping a
hop is rejected:

```bash
kubectl -n mesh-demo exec deploy/frontend-v1 -c frontend -- \
  python -c "import httpx; print(httpx.get('http://inventory:8000/stock').text)"
# RBAC: access denied

kubectl -n mesh-demo exec deploy/orders-v1 -c orders -- \
  python -c "import httpx; print(httpx.get('http://inventory:8000/stock').text)"
# {"service":"inventory",...}
```

### Traffic management

`manifests/50-traffic.yaml` holds the 90/10 split, retries, and a commented-out
fault-injection block. Edit the weights or uncomment `fault:` and re-apply:

```bash
kubectl apply -f istio-sandbox/manifests/50-traffic.yaml
```

### Observability

```bash
istioctl dashboard kiali      # service graph, mTLS lock icons, traffic split
istioctl dashboard jaeger     # traces: gateway → frontend → orders → inventory
istioctl dashboard grafana    # Istio mesh / service dashboards
```

Generate some traffic first (the canary loop above works) so there is something
to look at.
