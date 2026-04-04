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
    Environment = "dev"
    Project     = "recif"
    ManagedBy   = "terraform"
  }
}

# --- Kubernetes (EKS) ---

module "kubernetes" {
  source = "../../modules/kubernetes"

  cluster_name       = var.cluster_name
  region             = var.region
  node_count         = 2
  node_instance_type = "t3.medium"
  k8s_version        = "1.31"
  tags               = local.tags
}

# --- Database (RDS PostgreSQL) ---

module "database" {
  source = "../../modules/database"

  identifier        = "${var.cluster_name}-db"
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  vpc_id            = module.kubernetes.vpc_id
  subnet_ids        = module.kubernetes.private_subnet_ids
  db_name           = "recif"
  username          = "recif"
  password          = var.db_password
  multi_az          = false
  tags              = local.tags
}

# --- Recif (Helm) ---

module "recif" {
  source = "../../modules/helm-release"

  depends_on = [module.kubernetes, module.database]

  release_name = "recif"
  namespace    = "recif-system"
  chart_path   = "${path.module}/../../../helm/recif"

  helm_values = {
    "postgresql.enabled"               = "false"
    "api.env.AUTH_ENABLED"             = "false"
    "ollama.enabled"                   = "true"
    "ingress.enabled"                  = "false"
    "global.teamNamespace"             = "team-default"
  }
}
