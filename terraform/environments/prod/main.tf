terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }

  # Uncomment and configure for remote state
  # backend "s3" {
  #   bucket = "recif-terraform-state"
  #   key    = "prod/terraform.tfstate"
  #   region = "us-east-1"
  # }
}

provider "aws" {
  region = var.region
}

provider "helm" {
  kubernetes {
    host                   = module.kubernetes.cluster_endpoint
    cluster_ca_certificate = base64decode(module.kubernetes.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.kubernetes.cluster_name]
    }
  }
}

locals {
  tags = {
    Environment = "prod"
    Project     = "recif"
    ManagedBy   = "terraform"
  }
}

# --- Kubernetes (EKS) — HA configuration ---

module "kubernetes" {
  source = "../../modules/kubernetes"

  cluster_name       = var.cluster_name
  region             = var.region
  node_count         = 3
  node_instance_type = "t3.large"
  k8s_version        = "1.31"
  tags               = local.tags
}

# --- Database (RDS PostgreSQL) — Multi-AZ ---

module "database" {
  source = "../../modules/database"

  identifier          = "${var.cluster_name}-db"
  instance_class      = "db.r6g.large"
  allocated_storage   = 100
  vpc_id              = module.kubernetes.vpc_id
  subnet_ids          = module.kubernetes.private_subnet_ids
  db_name             = "recif"
  username            = "recif"
  password            = var.db_password
  multi_az            = true
  skip_final_snapshot = false
  deletion_protection = true
  tags                = local.tags
}

# --- Recif (Helm) — Production settings ---

module "recif" {
  source = "../../modules/helm-release"

  depends_on = [module.kubernetes, module.database]

  release_name = "recif"
  namespace    = "recif-system"
  chart_path   = "${path.module}/../../../helm/recif"

  helm_values = {
    "postgresql.enabled"               = "false"
    "api.replicas"                     = "3"
    "api.env.AUTH_ENABLED"             = "true"
    "api.env.LOG_LEVEL"                = "warn"
    "api.env.ENV_PROFILE"              = "prod"
    "operator.replicas"                = "2"
    "dashboard.replicas"               = "2"
    "ollama.enabled"                   = "false"
    "istio.enabled"                    = "true"
    "ingress.enabled"                  = "true"
    "ingress.host"                     = var.domain
    "ingress.tls"                      = "true"
    "global.teamNamespace"             = "team-default"
  }
}
