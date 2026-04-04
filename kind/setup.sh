#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${CYAN}Recif -- Local Development Setup${NC}"
echo ""

# Check prerequisites
for cmd in kind helm kubectl docker; do
  if ! command -v "$cmd" &>/dev/null; then
    echo -e "${YELLOW}$cmd not found. Please install it first.${NC}"
    exit 1
  fi
done

# Create Kind cluster
echo -e "${CYAN}Creating Kind cluster...${NC}"
if kind get clusters 2>/dev/null | grep -q recif; then
  echo "Cluster 'recif' already exists, skipping..."
else
  kind create cluster --config "${SCRIPT_DIR}/kind-config.yaml"
fi

# Build and load images into Kind
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
echo -e "${CYAN}Building images...${NC}"

docker build -t ghcr.io/sciences44/recif-api:latest \
  -f "${REPO_ROOT}/recif/Dockerfile" "${REPO_ROOT}/recif" -q
docker build -t ghcr.io/sciences44/recif-dashboard:latest \
  -f "${REPO_ROOT}/recif/dashboard/Dockerfile" "${REPO_ROOT}/recif/dashboard" -q
docker build -t ghcr.io/sciences44/recif-operator:latest \
  -f "${REPO_ROOT}/recif-operator/Dockerfile" "${REPO_ROOT}/recif-operator" -q
docker build -t recif-mlflow:latest \
  -f "${REPO_ROOT}/deploy/mlflow/Dockerfile" "${REPO_ROOT}/deploy/mlflow" -q

echo -e "${CYAN}Loading images into Kind...${NC}"
for img in recif-api recif-dashboard recif-operator; do
  kind load docker-image "ghcr.io/sciences44/${img}:latest" --name recif
done
kind load docker-image recif-mlflow:latest --name recif

# Deploy MLflow (central to the platform)
echo -e "${CYAN}Deploying MLflow...${NC}"
kubectl apply -f "${REPO_ROOT}/deploy/mlflow/deployment.yaml"

# Prepare namespaces
echo -e "${CYAN}Preparing namespaces...${NC}"
kubectl create namespace recif-system --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace recif-system app.kubernetes.io/managed-by=Helm --overwrite
kubectl annotate namespace recif-system meta.helm.sh/release-name=recif meta.helm.sh/release-namespace=recif-system --overwrite
kubectl create namespace team-default --dry-run=client -o yaml | kubectl apply -f -

# Install Helm chart
echo -e "${CYAN}Installing Recif via Helm...${NC}"
helm upgrade --install recif "${SCRIPT_DIR}/../helm/recif" \
  --namespace recif-system \
  --set ollama.enabled=true \
  --set ingress.enabled=false

# Wait for core pods (skip Ollama — it may take a long time to pull models)
echo -e "${CYAN}Waiting for core pods...${NC}"
kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=api -n recif-system --timeout=120s || true
kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=dashboard -n recif-system --timeout=120s || true
kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=operator -n recif-system --timeout=120s || true
kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=postgresql -n recif-system --timeout=120s || true
echo -e "${YELLOW}Note: Ollama may still be downloading models in the background${NC}"

echo ""
echo -e "${GREEN}Recif is ready!${NC}"
echo ""
echo "  Dashboard:  http://localhost:3000"
echo "  API:        http://localhost:8080"
echo "  PostgreSQL: localhost:5432"
echo ""
echo "Run port-forwards:"
echo "  kubectl port-forward svc/recif-api 8080:8080 -n recif-system"
echo "  kubectl port-forward svc/recif-dashboard 3000:3000 -n recif-system"
