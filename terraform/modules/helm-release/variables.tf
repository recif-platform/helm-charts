variable "release_name" {
  description = "Helm release name"
  type        = string
  default     = "recif"
}

variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
  default     = "recif-system"
}

variable "chart_path" {
  description = "Path to the Helm chart"
  type        = string
}

variable "helm_values" {
  description = "Map of Helm values to set"
  type        = map(string)
  default     = {}
}
