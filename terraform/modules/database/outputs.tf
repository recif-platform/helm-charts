output "endpoint" {
  description = "RDS endpoint"
  value       = aws_db_instance.postgres.endpoint
}

output "port" {
  description = "RDS port"
  value       = aws_db_instance.postgres.port
}

output "connection_string" {
  description = "PostgreSQL connection string"
  value       = "postgres://${var.username}:${var.password}@${aws_db_instance.postgres.endpoint}/${var.db_name}?sslmode=require"
  sensitive   = true
}

output "database_name" {
  description = "Database name"
  value       = aws_db_instance.postgres.db_name
}
