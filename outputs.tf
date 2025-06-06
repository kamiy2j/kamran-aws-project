output "alb_dns_name" {
  description = "DNS name of the load balancer"
  value       = aws_lb.main.dns_name
}

output "app_url" {
  description = "Application URL"
  value       = "https://app.${var.domain_name}"
}

output "bi_tool_url" {
  description = "BI Tool URL"
  value       = "http://bi.${var.domain_name}:5000"
}

output "mysql_endpoint" {
  description = "MySQL RDS endpoint"
  value       = aws_db_instance.mysql.endpoint
  sensitive   = true
}

output "postgresql_endpoint" {
  description = "PostgreSQL RDS endpoint"
  value       = aws_db_instance.postgresql.endpoint
  sensitive   = true
}

output "bi_tool_public_ip" {
  description = "BI Tool instance public IP"
  value       = aws_instance.bi_tool.public_ip
}