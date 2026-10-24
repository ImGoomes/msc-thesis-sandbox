#!/usr/bin/env bash
# Create the kind cluster, install Istio (ambient) + addons, build/load the apps and deploy them.
# App code and the manifests that are identical in both modes come from ../istio-sandbox.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SIDECAR="$ROOT/../istio-sandbox"
CLUSTER="${CLUSTER:-mesh-ambient}"
ISTIO_VERSION="${ISTIO_VERSION:-1.31.2}"
ISTIO_DIR="${ISTIO_DIR:-$HOME/.local/opt/istio-$ISTIO_VERSION}"
GATEWAY_API_VERSION="${GATEWAY_API_VERSION:-v1.4.0}"
TAG=0.1
APPS=(frontend orders inventory)
SHARED_MANIFESTS=(10-apps 20-mtls 40-gateway 50-traffic)

for bin in docker kind kubectl; do
  command -v "$bin" >/dev/null || { echo "missing '$bin' — see istio-ambient-sandbox/README.md"; exit 1; }
done

# istioctl + samples/addons come from the Istio release archive.
if [[ ! -x "$ISTIO_DIR/bin/istioctl" ]]; then
  echo ">> downloading Istio $ISTIO_VERSION to $ISTIO_DIR"
  mkdir -p "$(dirname "$ISTIO_DIR")"
  (cd "$(dirname "$ISTIO_DIR")" && curl -sL https://istio.io/downloadIstio | ISTIO_VERSION="$ISTIO_VERSION" sh -)
fi
ISTIOCTL="$ISTIO_DIR/bin/istioctl"

if ! kind get clusters | grep -qx "$CLUSTER"; then
  echo ">> creating kind cluster '$CLUSTER'"
  kind create cluster --name "$CLUSTER" --config "$ROOT/kind-config.yaml"
fi
kubectl config use-context "kind-$CLUSTER" >/dev/null

# Waypoints are Gateway API `Gateway`s, so the CRDs must exist first.
echo ">> installing Gateway API CRDs ($GATEWAY_API_VERSION)"
kubectl get crd gateways.gateway.networking.k8s.io >/dev/null 2>&1 ||
  kubectl apply -f "https://github.com/kubernetes-sigs/gateway-api/releases/download/$GATEWAY_API_VERSION/standard-install.yaml"

echo ">> installing Istio (ambient)"
"$ISTIOCTL" install -y -f "$ROOT/istio/operator.yaml"
kubectl apply -f "$SIDECAR/istio/telemetry.yaml"

echo ">> installing addons (prometheus, grafana, kiali, jaeger)"
for addon in prometheus grafana kiali jaeger; do
  # kiali's CRDs can race on first apply; retry once.
  kubectl apply -f "$ISTIO_DIR/samples/addons/$addon.yaml" ||
    { sleep 5; kubectl apply -f "$ISTIO_DIR/samples/addons/$addon.yaml"; }
done

echo ">> building and loading app images"
for app in "${APPS[@]}"; do
  docker build -q -t "mesh-demo/$app:$TAG" --build-arg APP="$app" "$SIDECAR/apps"
  kind load docker-image --name "$CLUSTER" "mesh-demo/$app:$TAG"
done

echo ">> deploying apps"
kubectl apply -f "$ROOT/manifests/00-namespace.yaml"
for m in "${SHARED_MANIFESTS[@]}"; do
  kubectl apply -f "$SIDECAR/manifests/$m.yaml"
done
kubectl apply -f "$ROOT/manifests/"
kubectl -n mesh-demo rollout restart deploy -l '!gateway.networking.k8s.io/gateway-name' >/dev/null  # pick up rebuilt images on re-runs
kubectl -n mesh-demo wait --for=condition=available deploy --all --timeout=300s
kubectl -n istio-system wait --for=condition=available deploy --all --timeout=300s
for ds in ztunnel istio-cni-node; do
  kubectl -n istio-system rollout status "ds/$ds" --timeout=300s
done

echo
echo "Ready. Try:  curl -s localhost:8081/ | python3 -m json.tool"
echo "Dashboards:  $ISTIOCTL dashboard kiali   (also: grafana, jaeger, prometheus)"
