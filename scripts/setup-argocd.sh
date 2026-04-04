#!/usr/bin/env bash
# Install ArgoCD Core and enable it in the Récif Helm chart.
#
# Usage:
#   RECIF_STATE_TOKEN=ghp_xxx ./deploy/scripts/setup-argocd.sh
#
# What this does:
#   1. kubectl apply — installs ArgoCD Core (headless, no UI)
#   2. helm upgrade — enables argocd in the Récif chart (RBAC, ApplicationSet, health checks, secret)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ -z "${RECIF_STATE_TOKEN:-}" ]; then
  echo -e "${YELLOW}RECIF_STATE_TOKEN not set.${NC}"
  echo "Usage: RECIF_STATE_TOKEN=ghp_xxx $0"
  exit 1
fi

# ── Step 1: Install ArgoCD Core ─────────────────────────────────────────────
echo -e "${CYAN}[1/2] Installing ArgoCD Core (headless)...${NC}"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.14.14/manifests/core-install.yaml

echo "  Waiting for controllers..."
kubectl wait --for=condition=Available deployment/argocd-repo-server -n argocd --timeout=120s 2>/dev/null || true
kubectl wait --for=condition=Available deployment/argocd-applicationset-controller -n argocd --timeout=120s 2>/dev/null || true

# ── Step 2: Enable ArgoCD in Helm chart ─────────────────────────────────────
echo -e "${CYAN}[2/2] Enabling ArgoCD in Récif Helm chart...${NC}"
helm upgrade --install recif "${REPO_ROOT}/deploy/helm/recif" \
  --namespace recif-system \
  --set argocd.enabled=true \
  --set argocd.stateToken="${RECIF_STATE_TOKEN}" \
  --set ingress.enabled=false

echo ""
echo -e "${GREEN}Done! ArgoCD is installed and configured.${NC}"
echo ""
echo "  Check ArgoCD:   kubectl get pods -n argocd"
echo "  Check agents:   kubectl get applications -n argocd"
echo "  State repo:     https://github.com/recif-platform/recif-state"
echo ""
