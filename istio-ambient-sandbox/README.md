# Istio ambient sandbox

The [sidecar sandbox](../istio-sandbox/) with Istio in
[ambient mode](https://istio.io/latest/docs/ambient/overview/) instead: same apps,
same call chain, same policies, no sidecars.

```
curl :8081 ──► istio-ingressgateway ──► frontend ──► waypoint ──► orders ──► waypoint ──► inventory v1 (90%)
                                                                                     └─► inventory v2 (10%)
```

Each node runs a `ztunnel` that handles mTLS and L4 policy for all pods on
that node. One shared Envoy, the namespace **waypoint**, handles L7 (HTTP
authz, canary split, retries, faults) for in-mesh calls.

| Path | What it is |
| --- | --- |
| `kind-config.yaml` | 1 control-plane + 2 workers, host port **8081** → gateway NodePort 30080 |
| `istio/` | `istioctl install` config (**ambient** profile, NodePort gateway, Jaeger tracing) |
| `manifests/` | Only the files that differ from the sidecar sandbox (namespace, waypoint, authz) |
| `scripts/` | `up.sh` / `down.sh` |

`up.sh` reuses the parts that are the same in both modes from `../istio-sandbox`:
`apps/`, `istio/telemetry.yaml` and `manifests/{10-apps,20-mtls,40-gateway,50-traffic}.yaml`.
That way the diff between the two directories is the difference between the modes.

The cluster is named `mesh-ambient` and listens on port 8081, so it can run
alongside the sidecar cluster (`mesh`, port 8080).

## What changes compared with sidecar mode

| | Sidecar (`../istio-sandbox`) | Ambient (here) |
| --- | --- | --- |
| Install | `profile: demo` | `profile: ambient` (+ istio-cni, ztunnel DaemonSets) + Gateway API CRDs |
| Joining the mesh | `istio-injection: enabled` → Envoy in every pod | `istio.io/dataplane-mode: ambient` → pods unchanged |
| L7 proxy | one per pod | one `waypoint` per namespace (`05-waypoint.yaml`) |
| mTLS | sidecar ↔ sidecar | ztunnel ↔ ztunnel (HBONE) |
| AuthorizationPolicy | `selector`, L4 + L7 in the sidecar | L4 at ztunnel (`selector`), L7 at waypoint (`targetRefs`) |
| Traffic rules (`50-traffic.yaml`) | client sidecar | waypoint (same VirtualService/DestinationRule) |

The authz split is the least obvious part. ztunnel only sees L4. Calls to
`orders` and `inventory` reach their ztunnel *from the waypoint*, so ztunnel
just trusts the waypoint's identity, and the per-caller method/path checks
happen in the waypoint. See the comments in `manifests/30-authz.yaml`.

## Install the tools

Same as the sidecar sandbox (`kind`, `kubectl`, Docker without `sudo`). The
Istio release is shared too (`~/.local/opt/istio-<version>`).

## Run it

```bash
./istio-ambient-sandbox/scripts/up.sh
```

Pods have a single container. The mesh lives in `istio-system`:

```bash
kubectl get pods -n mesh-demo                     # 1/1, plus the waypoint pod
kubectl get pods -n istio-system                  # ztunnel + istio-cni-node on every node
istioctl ztunnel-config workloads                 # PROTOCOL should be HBONE for mesh-demo
```

Call the chain and count the canary split:

```bash
curl -s localhost:8081/ | python3 -m json.tool
for i in $(seq 50); do curl -s localhost:8081/ | grep -o '"version":"v."'; done | sort | uniq -c
```

Tear down:

```bash
./istio-ambient-sandbox/scripts/down.sh
```

## Things to try

The checks from the sidecar README still apply. Only the gateway port changes:

```bash
# mTLS: plaintext from outside the mesh is rejected by ztunnel
kubectl run plain --rm -it --restart=Never --image=curlimages/curl -- \
  curl -sv http://orders.mesh-demo:8000/orders

# authz: skipping a hop is rejected by the waypoint
kubectl -n mesh-demo exec deploy/frontend-v1 -c frontend -- \
  python -c "import httpx; print(httpx.get('http://inventory:8000/stock').text)"
# RBAC: access denied
```

To see which proxy enforces what:

```bash
kubectl -n istio-system logs ds/ztunnel | grep -i deny     # L4 decisions
kubectl -n mesh-demo logs deploy/waypoint                  # L7 decisions / access log
```

To compare the two modes, run both clusters, send the same load to
`localhost:8080` and `localhost:8081`, and compare:

- data-plane footprint: `docker stats` on the kind nodes, or the Grafana
  *Istio Performance* dashboard
- request latency from the client (e.g. `hey`/`fortio` against each port)
- trace shape in Jaeger: the sidecar cluster has 2 spans per hop, the ambient
  cluster has spans only from the gateway and the waypoint
