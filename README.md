# :rocket: Recif Helm Charts

[![Helm 3](https://img.shields.io/badge/Helm-3.x-0f1689?logo=helm&logoColor=white)](https://helm.sh)
[![Kubernetes 1.28+](https://img.shields.io/badge/Kubernetes-1.28%2B-326ce5?logo=kubernetes&logoColor=white)](https://kubernetes.io)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](../LICENSE)
[![Discord](https://img.shields.io/badge/Discord-Join-5865F2?logo=discord&logoColor=white)](https://discord.gg/P279TT4ZCp)

Helm charts, deployment scripts, and infrastructure-as-code for the **Récif** agentic AI platform. One `helm install` to get the full platform running on any Kubernetes cluster.

> **⚠️ Alpha Release** — Récif has just been open-sourced. Expect breaking changes and evolving configurations. We welcome **contributors** of all backgrounds.
>
> **[Join us on Discord →](https://discord.gg/P279TT4ZCp)** · **[Quickstart →](https://recif-platform.github.io/docs/quickstart)**

---

## Table of Contents

- [Quick Start](#quick-start)
- [What's Included](#whats-included)
- [Architecture](#architecture)
- [Helm Values Reference](#helm-values-reference)
- [Credential Setup](#credential-setup)
- [Local Development (Kind)](#local-development-kind)
- [Production Deployment (Terraform)](#production-deployment-terraform)
- [Canary Deployments (Flagger)](#canary-deployments-flagger)
- [MLflow Integration](#mlflow-integration)
- [Uninstall](#uninstall)

---

## Quick Start

**Prerequisites:** A running Kubernetes cluster (Kind, Colima, EKS, GKE, AKS...), `helm`, and `kubectl`.

```bash
# 1. Install the platform
helm install recif helm/recif/ --namespace recif-system --create-namespace

# 2. Configure an LLM provider
./scripts/setup-credentials.sh --provider google-ai

# 3. Create your first agent
kubectl apply -f - <<EOF
apiVersion: agents.recif.dev/v1
kind: Agent
metadata:
  name: hello
  namespace: team-default
spec:
  name: hello
  framework: corail
  modelType: google-ai
  modelId: gemini-2.5-flash
  systemPrompt: "You are a helpful assistant."
EOF

# 4. Check agent status
kubectl get agents -n team-default
```

Or use the **one-liner installer** for local dev (installs Kind, builds images, deploys everything):

```bash
curl -sSL https://raw.githubusercontent.com/sciences44/agentic-platform/main/deploy/install.sh | bash
```

---

## What's Included

```
deploy/
├── helm/recif/              # Main Helm chart
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
│       ├── api-deployment.yaml
│       ├── api-service.yaml
│       ├── operator-deployment.yaml
│       ├── dashboard-deployment.yaml
│       ├── postgresql-statefulset.yaml
│       ├── ollama-deployment.yaml
│       ├── ingress.yaml
│       ├── rbac.yaml
│       ├── configmap.yaml
│       ├── agent-secrets.yaml
│       ├── namespace.yaml
│       ├── _helpers.tpl
│       └── crds/
│           └── agent-crd.yaml   # Agent + Tool CRDs
├── scripts/
│   └── setup-credentials.sh    # Interactive LLM credential setup
├── kind/                        # Local cluster (Kind) setup
│   ├── kind-config.yaml
│   ├── setup.sh
│   └── teardown.sh
├── mlflow/                      # MLflow for eval-driven lifecycle
│   ├── Dockerfile
│   ├── deployment.yaml
│   └── setup.sh
├── flagger/                     # Canary deployment support
│   ├── canary-template.yaml
│   └── setup.sh
├── terraform/                   # IaC for cloud deployments
│   ├── modules/
│   │   ├── kubernetes/
│   │   ├── database/
│   │   └── helm-release/
│   └── environments/
│       ├── dev/
│       └── prod/
└── install.sh                   # One-liner installer
```

### CRDs

The chart installs two Custom Resource Definitions:

| CRD | API Group | Description |
|-----|-----------|-------------|
| `Agent` | `agents.recif.dev/v1` | Defines an AI agent — model, framework, tools, replicas, canary config |
| `Tool` | `agents.recif.dev/v1` | Defines a tool (HTTP, CLI, MCP, builtin) available to agents |

---

## Architecture

```mermaid
graph TB
    subgraph K8s["Kubernetes Cluster"]
        subgraph NS_SYS["recif-system"]
            API["Recif API<br/><small>:8080</small>"]
            OP["Recif Operator<br/><small>watches Agent CRDs</small>"]
            DASH["Dashboard<br/><small>:3000</small>"]
            PG["PostgreSQL<br/><small>pgvector :5432</small>"]
            OLL["Ollama<br/><small>:11434 (optional)</small>"]
        end

        subgraph NS_TEAM["team-default"]
            A1["Agent Pod"]
            A2["Agent Pod"]
            A3["Agent Pod"]
        end

        subgraph NS_ML["mlflow-system"]
            ML["MLflow Server<br/><small>:5000</small>"]
            MLPG["PostgreSQL<br/><small>MLflow backend</small>"]
        end
    end

    USER["User / Client"] -->|REST / SSE| API
    USER -->|Browser| DASH
    DASH --> API
    API --> PG
    OP -->|creates/manages| A1
    OP -->|creates/manages| A2
    OP -->|creates/manages| A3
    A1 --> OLL
    A1 --> PG
    API --> ML
    OP -.->|watches| CRD["Agent & Tool CRDs"]

    style NS_SYS fill:#0d1b2a,stroke:#00b4d8,color:#e0e0e0
    style NS_TEAM fill:#0d1b2a,stroke:#48bb78,color:#e0e0e0
    style NS_ML fill:#0d1b2a,stroke:#ed8936,color:#e0e0e0
    style K8s fill:#1a1a2e,stroke:#555,color:#e0e0e0
```

**Flow:** The Operator watches for `Agent` CRDs and creates Deployments + Services in team namespaces. The API is the control plane. The Dashboard provides a web UI. Agents connect to LLM providers (cloud or Ollama) and persist state in PostgreSQL with pgvector for RAG.

---

## Helm Values Reference

### Key Sections

| Section | Key | Default | Description |
|---------|-----|---------|-------------|
| **api** | `api.image` | `ghcr.io/sciences44/recif-api` | API server image |
| | `api.port` | `8080` | Service port |
| | `api.replicas` | `1` | Replica count |
| | `api.env.AUTH_ENABLED` | `"false"` | Enable authentication |
| | `api.env.LOG_LEVEL` | `"info"` | Log level |
| | `api.env.ENV_PROFILE` | `"dev"` | Environment profile |
| **operator** | `operator.image` | `ghcr.io/sciences44/recif-operator` | Operator image |
| | `operator.replicas` | `1` | Replica count |
| **dashboard** | `dashboard.enabled` | `true` | Deploy the web dashboard |
| | `dashboard.image` | `ghcr.io/sciences44/recif-dashboard` | Dashboard image |
| | `dashboard.port` | `3000` | Service port |
| | `dashboard.apiUrl` | `""` | Override `NEXT_PUBLIC_API_URL` |
| **postgresql** | `postgresql.enabled` | `true` | Deploy bundled PostgreSQL |
| | `postgresql.image` | `pgvector/pgvector:pg16` | Image (includes pgvector) |
| | `postgresql.storage` | `10Gi` | PVC size |
| | `postgresql.credentials.database` | `recif` | Database name |
| | `postgresql.credentials.username` | `recif` | Username |
| | `postgresql.credentials.password` | `recif_dev` | Password (override in prod) |
| **corail** | `corail.image` | `ghcr.io/sciences44/corail` | Default agent runtime image |
| | `corail.defaultModel` | `ollama/qwen3.5:4b` | Default model for new agents |
| **ollama** | `ollama.enabled` | `true` | Deploy Ollama for local models |
| | `ollama.image` | `ollama/ollama:latest` | Ollama image |
| | `ollama.storage` | `20Gi` | PVC for model weights |
| | `ollama.port` | `11434` | Service port |
| | `ollama.gpu` | `false` | Enable GPU scheduling |
| | `ollama.models` | `[qwen3.5:4b, nomic-embed-text]` | Models to pull on startup |
| **llm** | `llm.googleApiKey` | `""` | Google AI API key |
| | `llm.openaiApiKey` | `""` | OpenAI API key |
| | `llm.anthropicApiKey` | `""` | Anthropic API key |
| | `llm.awsRegion` | `""` | AWS region (Bedrock) |
| | `llm.awsAccessKeyId` | `""` | AWS access key (Bedrock) |
| | `llm.awsSecretAccessKey` | `""` | AWS secret key (Bedrock) |
| | `llm.gcp.project` | `""` | GCP project ID (Vertex AI) |
| | `llm.gcp.location` | `us-central1` | GCP region (Vertex AI) |
| **istio** | `istio.enabled` | `false` | Enable Istio sidecar injection |
| **ingress** | `ingress.enabled` | `false` | Deploy Ingress resource |
| | `ingress.className` | `nginx` | Ingress class |
| | `ingress.host` | `recif.local` | Hostname |
| | `ingress.tls` | `false` | Enable TLS |
| **global** | `global.imageTag` | `latest` | Image tag for all Recif images |
| | `global.imagePullPolicy` | `IfNotPresent` | Pull policy |
| | `global.teamNamespace` | `team-default` | Default namespace for agents |

<details>
<summary><strong>Full values.yaml</strong></summary>

```yaml
global:
  imageTag: "latest"
  imagePullPolicy: IfNotPresent
  teamNamespace: "team-default"

api:
  replicas: 1
  image: ghcr.io/sciences44/recif-api
  port: 8080
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 512Mi
  env:
    AUTH_ENABLED: "false"
    LOG_LEVEL: "info"
    LOG_FORMAT: "json"
    ENV_PROFILE: "dev"

operator:
  replicas: 1
  image: ghcr.io/sciences44/recif-operator
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 256Mi

dashboard:
  enabled: true
  replicas: 1
  image: ghcr.io/sciences44/recif-dashboard
  port: 3000
  apiUrl: ""
  resources:
    requests:
      cpu: 50m
      memory: 64Mi
    limits:
      cpu: 200m
      memory: 256Mi

postgresql:
  enabled: true
  image: pgvector/pgvector:pg16
  storage: 10Gi
  port: 5432
  credentials:
    database: recif
    username: recif
    password: recif_dev

corail:
  image: ghcr.io/sciences44/corail
  defaultModel: "ollama/qwen3.5:4b"

ollama:
  enabled: true
  image: ollama/ollama:latest
  storage: 20Gi
  port: 11434
  gpu: false
  models:
    - qwen3.5:4b
    - nomic-embed-text

llm:
  googleApiKey: ""
  openaiApiKey: ""
  anthropicApiKey: ""
  awsRegion: ""
  awsAccessKeyId: ""
  awsSecretAccessKey: ""
  gcp:
    project: ""
    location: "us-central1"

istio:
  enabled: false

ingress:
  enabled: false
  className: nginx
  host: recif.local
  tls: false
```

</details>

---

## Credential Setup

Use the interactive script or pass values directly via Helm.

### Interactive Script

```bash
./scripts/setup-credentials.sh --provider <name> [--namespace <ns>]
```

### Supported Providers

| Provider | Flag | What You Need | Key URL |
|----------|------|---------------|---------|
| **Google AI** | `--provider google-ai` | API key | [aistudio.google.com/apikey](https://aistudio.google.com/apikey) |
| **OpenAI** | `--provider openai` | API key | [platform.openai.com/api-keys](https://platform.openai.com/api-keys) |
| **Anthropic** | `--provider anthropic` | API key | [console.anthropic.com/settings/keys](https://console.anthropic.com/settings/keys) |
| **Vertex AI** | `--provider vertex-ai` | GCP project + service account or ADC | [console.cloud.google.com](https://console.cloud.google.com) |
| **AWS Bedrock** | Helm values only | AWS access key + secret + region | [aws.amazon.com/bedrock](https://aws.amazon.com/bedrock/) |
| **Ollama** | No setup needed | `ollama.enabled: true` in Helm values | Local models, no API key |

### Via Helm Values (non-interactive)

```bash
helm install recif helm/recif/ \
  --namespace recif-system \
  --create-namespace \
  --set llm.googleApiKey="YOUR_KEY"
```

### Via Existing Secret

If you manage secrets externally (Vault, Sealed Secrets, etc.), create a secret named `agent-env` in the team namespace:

```bash
kubectl create secret generic agent-env \
  -n team-default \
  --from-literal=GOOGLE_API_KEY="..." \
  --from-literal=OPENAI_API_KEY="..."
```

---

## Local Development (Kind)

The fastest way to get a full cluster running locally:

```bash
# Setup (creates cluster, builds images, deploys everything)
cd deploy/kind
./setup.sh

# Access
kubectl port-forward svc/recif-api 8080:8080 -n recif-system
kubectl port-forward svc/recif-dashboard 3000:3000 -n recif-system

# Teardown
./teardown.sh
```

The Kind cluster runs 1 control-plane + 2 worker nodes with port mappings for 80, 443, 8080, and 3000.

---

## Production Deployment (Terraform)

Terraform modules are provided for AWS EKS. Adapt for GKE/AKS as needed.

```bash
cd deploy/terraform/environments/dev
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

terraform init
terraform plan
terraform apply
```

Modules:

| Module | Creates |
|--------|---------|
| `modules/kubernetes` | EKS cluster, VPC, node group |
| `modules/database` | RDS PostgreSQL instance |
| `modules/helm-release` | Recif Helm release |

For production, disable the bundled PostgreSQL and point to RDS:

```bash
helm install recif helm/recif/ \
  --namespace recif-system \
  --set postgresql.enabled=false \
  --set api.env.DATABASE_URL="postgres://user:pass@rds-host:5432/recif"
```

---

## Canary Deployments (Flagger)

Agent CRDs support a `canary` spec for progressive delivery via [Flagger](https://flagger.app):

```bash
# Install Flagger (requires Istio)
./deploy/flagger/setup.sh
```

Then configure canary on an agent:

```yaml
apiVersion: agents.recif.dev/v1
kind: Agent
metadata:
  name: my-agent
  namespace: team-default
spec:
  name: my-agent
  framework: corail
  modelType: google-ai
  modelId: gemini-2.5-flash
  canary:
    enabled: true
    weight: 20
    modelId: gemini-2.5-pro
    version: "v2"
```

Flagger analysis runs every 30s, checking request success rate (>99%) and latency (<2s), stepping traffic weight by 10% up to 50%.

---

## MLflow Integration

MLflow provides the eval-driven lifecycle (tracing, scorers, dataset management):

```bash
# Deploy MLflow (already included in kind/setup.sh)
kubectl apply -f deploy/mlflow/deployment.yaml

# Access
kubectl port-forward svc/mlflow 5000:5000 -n mlflow-system
```

MLflow runs in its own namespace (`mlflow-system`) with a dedicated PostgreSQL backend and persistent artifact storage.

---

## Uninstall

```bash
# Remove the Helm release
helm uninstall recif -n recif-system

# Remove MLflow
kubectl delete -f deploy/mlflow/deployment.yaml

# Remove CRDs (if desired)
kubectl delete crd agents.agents.recif.dev tools.agents.recif.dev

# Remove namespaces
kubectl delete namespace recif-system team-default mlflow-system

# Tear down Kind cluster (local dev only)
cd deploy/kind && ./teardown.sh
```

---

## License

Apache 2.0 -- See [LICENSE](../LICENSE) for details.
