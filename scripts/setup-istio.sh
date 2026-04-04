#!/bin/bash
# Install Istio + Kiali for Recif canary deployments
# Requires: istioctl (brew install istioctl)

set -euo pipefail

echo "=== Recif: Istio + Kiali Setup ==="
echo ""

# Check prerequisites
if ! command -v istioctl &> /dev/null; then
  echo "ERROR: istioctl not found."
  echo "  Install: brew install istioctl"
  echo "  Or: curl -L https://istio.io/downloadIstio | sh -"
  exit 1
fi

if ! command -v kubectl &> /dev/null; then
  echo "ERROR: kubectl not found."
  exit 1
fi

echo "Installing Istio (demo profile)..."
istioctl install --set profile=demo -y

echo ""
echo "Waiting for Istio pods to be ready..."
kubectl wait --for=condition=Ready pods --all -n istio-system --timeout=120s

echo ""
echo "Installing Prometheus (required by Kiali)..."
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.24/samples/addons/prometheus.yaml

echo ""
echo "Installing Kiali..."
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.24/samples/addons/kiali.yaml

echo ""
echo "Enabling Istio injection on team-default namespace..."
kubectl create namespace team-default 2>/dev/null || true
kubectl label namespace team-default istio-injection=enabled --overwrite

echo ""
echo "Waiting for Kiali to be ready..."
kubectl wait --for=condition=Ready pods -l app=kiali -n istio-system --timeout=120s

echo ""
echo "================================================"
echo "  Istio + Kiali installed successfully!"
echo "================================================"
echo ""
echo "  Kiali dashboard:"
echo "    kubectl port-forward -n istio-system svc/kiali 20001:20001"
echo "    Open: http://localhost:20001"
echo ""
echo "  Istio dashboard:"
echo "    istioctl dashboard envoy <pod-name>"
echo ""
echo "  Verify injection:"
echo "    kubectl get namespace team-default --show-labels"
echo ""
