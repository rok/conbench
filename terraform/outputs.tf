# VPC Outputs
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

# EKS Outputs
output "eks_cluster_id" {
  description = "EKS cluster ID"
  value       = aws_eks_cluster.conbench.id
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.conbench.name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = aws_eks_cluster.conbench.endpoint
}

output "eks_cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = aws_eks_cluster.conbench.vpc_config[0].cluster_security_group_id
}

output "eks_cluster_certificate_authority" {
  description = "EKS cluster certificate authority data"
  value       = aws_eks_cluster.conbench.certificate_authority[0].data
  sensitive   = true
}

output "eks_cluster_oidc_issuer_url" {
  description = "OIDC issuer URL for the EKS cluster"
  value       = aws_eks_cluster.conbench.identity[0].oidc[0].issuer
}

output "eks_node_group_id" {
  description = "EKS node group ID"
  value       = aws_eks_node_group.conbench.id
}

output "eks_node_group_status" {
  description = "Status of the EKS node group"
  value       = aws_eks_node_group.conbench.status
}

# RDS Outputs
output "rds_instance_id" {
  description = "RDS instance ID"
  value       = aws_db_instance.conbench.id
}

output "rds_instance_endpoint" {
  description = "RDS instance connection endpoint"
  value       = aws_db_instance.conbench.endpoint
}

output "rds_instance_address" {
  description = "RDS instance address (hostname)"
  value       = aws_db_instance.conbench.address
}

output "rds_instance_port" {
  description = "RDS instance port"
  value       = aws_db_instance.conbench.port
}

output "rds_database_name" {
  description = "Name of the database"
  value       = aws_db_instance.conbench.db_name
}

output "rds_master_username" {
  description = "Master username for RDS"
  value       = aws_db_instance.conbench.username
  sensitive   = true
}

# Security Group Outputs
output "eks_nodes_security_group_id" {
  description = "Security group ID for EKS worker nodes"
  value       = aws_security_group.eks_nodes.id
}

output "rds_security_group_id" {
  description = "Security group ID for RDS instance"
  value       = aws_security_group.rds.id
}

# Configuration Outputs
output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.conbench.name}"
}

output "db_connection_string" {
  description = "Database connection information (use with caution in logs)"
  value       = "postgresql://${aws_db_instance.conbench.username}@${aws_db_instance.conbench.address}:${aws_db_instance.conbench.port}/${aws_db_instance.conbench.db_name}"
  sensitive   = true
}
