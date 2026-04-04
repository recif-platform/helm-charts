#!/bin/bash
set -euo pipefail

echo "Removing Recif cluster..."
kind delete cluster --name recif
echo "Done."
