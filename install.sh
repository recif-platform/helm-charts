#!/bin/bash
# Recif -- One-liner installer for local development
# Usage: curl -sSL https://raw.githubusercontent.com/recif-platform/recif/main/deploy/install.sh | bash
set -euo pipefail

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}Recif -- Platform Installer${NC}"
echo ""

# Detect OS
OS="$(uname -s)"
case "$OS" in
  Darwin) PLATFORM="macos" ;;
  Linux)  PLATFORM="linux" ;;
  *)
    echo -e "${RED}Unsupported OS: $OS${NC}"
    exit 1
    ;;
esac
echo "Detected platform: $PLATFORM"

# Helper: check if command exists
has_cmd() {
  command -v "$1" &>/dev/null
}

# Helper: install a tool
install_tool() {
  local tool="$1"
  echo -e "${YELLOW}Installing $tool...${NC}"

  case "$tool" in
    docker)
      echo -e "${RED}Docker must be installed manually.${NC}"
      if [ "$PLATFORM" = "macos" ]; then
        echo "  Download: https://www.docker.com/products/docker-desktop/"
      else
        echo "  Run: curl -fsSL https://get.docker.com | sh"
      fi
      exit 1
      ;;
    kind)
      if [ "$PLATFORM" = "macos" ]; then
        brew install kind
      else
        curl -Lo ./kind https://kind.sigs.k8s.io/dl/latest/kind-linux-amd64
        chmod +x ./kind
        sudo mv ./kind /usr/local/bin/kind
      fi
      ;;
    helm)
      if [ "$PLATFORM" = "macos" ]; then
        brew install helm
      else
        curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
      fi
      ;;
    kubectl)
      if [ "$PLATFORM" = "macos" ]; then
        brew install kubectl
      else
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        chmod +x kubectl
        sudo mv kubectl /usr/local/bin/kubectl
      fi
      ;;
  esac
}

# Check and install prerequisites
for tool in docker kind helm kubectl; do
  if has_cmd "$tool"; then
    echo -e "  ${GREEN}$tool${NC} found"
  else
    install_tool "$tool"
  fi
done

echo ""

# Clone repo if not already in it
REPO_DIR=""
if [ -f "deploy/kind/setup.sh" ]; then
  REPO_DIR="."
elif [ -f "kind/setup.sh" ]; then
  REPO_DIR=".."
else
  echo -e "${CYAN}Cloning Recif repository...${NC}"
  git clone https://github.com/recif-platform/recif.git recif-platform
  REPO_DIR="recif-platform"
fi

# Run Kind setup
echo -e "${CYAN}Running Kind cluster setup...${NC}"
cd "$REPO_DIR/deploy/kind"
bash setup.sh

echo ""
echo -e "${GREEN}Installation complete!${NC}"
echo ""
echo "  Dashboard:  http://localhost:3000"
echo "  API:        http://localhost:8080"
echo ""
echo "To tear down: cd deploy/kind && ./teardown.sh"
