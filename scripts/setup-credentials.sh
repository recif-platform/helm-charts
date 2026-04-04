#!/bin/bash
# setup-credentials.sh — Configure LLM provider credentials for Récif
#
# Usage:
#   ./deploy/scripts/setup-credentials.sh [--provider <name>] [--namespace <ns>]
#
# Providers: google-ai, openai, anthropic, vertex-ai, ollama (no setup needed)
#
# Examples:
#   ./deploy/scripts/setup-credentials.sh --provider google-ai
#   ./deploy/scripts/setup-credentials.sh --provider vertex-ai --namespace team-default
#   ./deploy/scripts/setup-credentials.sh --provider openai

set -euo pipefail

NAMESPACE="${NAMESPACE:-team-default}"
PROVIDER=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --provider) PROVIDER="$2"; shift 2 ;;
    --namespace) NAMESPACE="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [[ -z "$PROVIDER" ]]; then
  echo "╔══════════════════════════════════════════════════╗"
  echo "║  Récif — LLM Provider Setup                     ║"
  echo "╚══════════════════════════════════════════════════╝"
  echo ""
  echo "Choose a provider:"
  echo ""
  echo "  1) google-ai    — Gemini via API key (easiest, free tier)"
  echo "  2) openai        — GPT-4o, GPT-4o-mini"
  echo "  3) anthropic     — Claude Sonnet, Opus"
  echo "  4) vertex-ai     — Gemini via Google Cloud (production)"
  echo "  5) ollama        — Local models (no API key needed)"
  echo ""
  read -rp "Enter number (1-5): " choice
  case $choice in
    1) PROVIDER="google-ai" ;;
    2) PROVIDER="openai" ;;
    3) PROVIDER="anthropic" ;;
    4) PROVIDER="vertex-ai" ;;
    5) echo "✓ Ollama needs no credentials. Make sure ollama.enabled=true in Helm values."; exit 0 ;;
    *) echo "Invalid choice"; exit 1 ;;
  esac
fi

echo ""
echo "Setting up: $PROVIDER → namespace: $NAMESPACE"
echo ""

case $PROVIDER in
  google-ai)
    echo "Get your API key from: https://aistudio.google.com/apikey"
    read -rsp "Enter your Google AI API key: " API_KEY
    echo ""
    kubectl create secret generic agent-env -n "$NAMESPACE" \
      --from-literal=GOOGLE_API_KEY="$API_KEY" \
      --from-literal=GOOGLE_AI_API_KEY="$API_KEY" \
      --dry-run=client -o yaml | kubectl apply -f -
    echo "✓ Secret 'agent-env' created in namespace '$NAMESPACE'"
    echo ""
    echo "Use model type: google-ai"
    echo "Use model ID:   gemini-2.5-flash"
    ;;

  openai)
    echo "Get your API key from: https://platform.openai.com/api-keys"
    read -rsp "Enter your OpenAI API key: " API_KEY
    echo ""
    kubectl create secret generic agent-env -n "$NAMESPACE" \
      --from-literal=OPENAI_API_KEY="$API_KEY" \
      --dry-run=client -o yaml | kubectl apply -f -
    echo "✓ Secret 'agent-env' created in namespace '$NAMESPACE'"
    echo ""
    echo "Use model type: openai"
    echo "Use model ID:   gpt-4o-mini"
    ;;

  anthropic)
    echo "Get your API key from: https://console.anthropic.com/settings/keys"
    read -rsp "Enter your Anthropic API key: " API_KEY
    echo ""
    kubectl create secret generic agent-env -n "$NAMESPACE" \
      --from-literal=ANTHROPIC_API_KEY="$API_KEY" \
      --dry-run=client -o yaml | kubectl apply -f -
    echo "✓ Secret 'agent-env' created in namespace '$NAMESPACE'"
    echo ""
    echo "Use model type: anthropic"
    echo "Use model ID:   claude-sonnet-4-20250514"
    ;;

  vertex-ai)
    echo "Two options:"
    echo "  a) Service Account key (recommended — per-agent isolation)"
    echo "  b) Application Default Credentials (quick dev setup)"
    echo ""
    read -rp "Enter choice (a/b): " sa_choice

    case $sa_choice in
      a)
        read -rp "Agent name (K8s resource name): " AGENT_NAME
        read -rp "Path to service account JSON key: " SA_KEY_PATH

        if [[ ! -f "$SA_KEY_PATH" ]]; then
          echo "ERROR: File not found: $SA_KEY_PATH"
          exit 1
        fi

        # Extract SA email and project from the key file
        SA_EMAIL=$(python3 -c "import json; print(json.load(open('$SA_KEY_PATH'))['client_email'])" 2>/dev/null)
        PROJECT=$(python3 -c "import json; print(json.load(open('$SA_KEY_PATH'))['project_id'])" 2>/dev/null)

        echo ""
        echo "Service Account: $SA_EMAIL"
        echo "Project:         $PROJECT"
        echo ""

        # Create per-agent secret
        kubectl create secret generic "${AGENT_NAME}-gcp-sa" -n "$NAMESPACE" \
          --from-file=credentials.json="$SA_KEY_PATH" \
          --dry-run=client -o yaml | kubectl apply -f -

        echo "✓ Secret '${AGENT_NAME}-gcp-sa' created in namespace '$NAMESPACE'"
        echo ""
        echo "Now set in your Agent CRD or dashboard config:"
        echo "  spec.gcpServiceAccount: $SA_EMAIL"
        echo "  spec.modelType: vertex-ai"
        echo "  spec.modelId: gemini-2.5-flash"
        echo ""
        echo "The operator will automatically:"
        echo "  - Mount the credentials into the pod"
        echo "  - Set GOOGLE_APPLICATION_CREDENTIALS"
        echo "  - Set GOOGLE_CLOUD_PROJECT=$PROJECT"
        ;;

      b)
        read -rp "Enter your GCP project ID: " PROJECT
        read -rp "Enter GCP region [us-central1]: " LOCATION
        LOCATION="${LOCATION:-us-central1}"

        ADC_PATH="$HOME/.config/gcloud/application_default_credentials.json"
        if [[ ! -f "$ADC_PATH" ]]; then
          echo ""
          echo "No Application Default Credentials found."
          echo "Running: gcloud auth application-default login"
          gcloud auth application-default login
        fi

        if [[ ! -f "$ADC_PATH" ]]; then
          echo "ERROR: ADC file not found at $ADC_PATH"
          exit 1
        fi

        kubectl create secret generic gcp-adc -n "$NAMESPACE" \
          --from-file=adc.json="$ADC_PATH" \
          --dry-run=client -o yaml | kubectl apply -f -

        kubectl create secret generic agent-env -n "$NAMESPACE" \
          --from-literal=GOOGLE_CLOUD_PROJECT="$PROJECT" \
          --from-literal=GOOGLE_CLOUD_LOCATION="$LOCATION" \
          --dry-run=client -o yaml | kubectl apply -f -

        kubectl set env deployment/recif-operator -n recif-system \
          GOOGLE_CLOUD_PROJECT="$PROJECT" \
          GOOGLE_CLOUD_LOCATION="$LOCATION" 2>/dev/null || true

        echo ""
        echo "✓ Shared credentials created for all agents in '$NAMESPACE'"
        echo "✓ Operator updated with GCP project: $PROJECT"
        echo ""
        echo "Use model type: vertex-ai"
        echo "Use model ID:   gemini-2.5-flash"
        ;;

      *) echo "Invalid choice"; exit 1 ;;
    esac
    ;;
esac

echo ""
echo "Done! Create an agent with this model type in the dashboard or via CRD."
