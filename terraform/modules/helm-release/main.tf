terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

resource "helm_release" "recif" {
  name       = var.release_name
  namespace  = var.namespace
  chart      = var.chart_path

  create_namespace = true
  wait             = true
  timeout          = 600

  dynamic "set" {
    for_each = var.helm_values
    content {
      name  = set.key
      value = set.value
    }
  }
}
