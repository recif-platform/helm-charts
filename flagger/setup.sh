#!/bin/bash
set -e
echo "Installing Flagger with Istio provider..."
helm repo add flagger https://flagger.app
helm repo update
helm upgrade -i flagger flagger/flagger \
  --namespace istio-system \
  --set meshProvider=istio \
  --set metricsServer=http://prometheus:9090
echo "Flagger installed."
