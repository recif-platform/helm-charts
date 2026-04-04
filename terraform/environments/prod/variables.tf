variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "recif-prod"
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "domain" {
  description = "Domain name for the platform"
  type        = string
  default     = "recif.example.com"
}
