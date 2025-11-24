# General Variables
variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS CLI profile to use for authentication"
  type        = string
  default     = ""
}

variable "environment" {
  description = "Environment name (e.g., prod, staging, dev)"
  type        = string
  default     = "prod"
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access the EKS cluster"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Restrict this in production!
}

# VPC Variables
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

# EKS Variables
variable "kubernetes_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.28"
}

variable "node_group_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "node_group_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

variable "node_group_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 4
}

variable "node_instance_types" {
  description = "EC2 instance types for worker nodes"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_disk_size" {
  description = "Disk size in GB for worker nodes"
  type        = number
  default     = 20
}

# RDS Variables
variable "db_snapshot_identifier" {
  description = "RDS snapshot identifier to restore from (leave empty to create new instance)"
  type        = string
  default     = ""
}

variable "db_engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "15.5"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.medium"
}

variable "db_allocated_storage" {
  description = "Allocated storage in GB (not used if restoring from snapshot)"
  type        = number
  default     = 100
}

variable "db_max_allocated_storage" {
  description = "Maximum allocated storage in GB for autoscaling"
  type        = number
  default     = 500
}

variable "db_name" {
  description = "Database name (only used for new instances, not snapshots)"
  type        = string
  default     = "conbench"
}

variable "db_username" {
  description = "Master username (only used for new instances, not snapshots)"
  type        = string
  default     = "conbench_admin"
  sensitive   = true
}

variable "db_password" {
  description = "Master password (only used for new instances, not snapshots)"
  type        = string
  sensitive   = true
  default     = ""

  validation {
    condition     = var.db_password == "" || length(var.db_password) >= 8
    error_message = "Database password must be at least 8 characters long."
  }
}

variable "db_backup_retention_period" {
  description = "Number of days to retain automated backups"
  type        = number
  default     = 7
}

variable "db_multi_az" {
  description = "Enable Multi-AZ for high availability"
  type        = bool
  default     = false
}

variable "db_skip_final_snapshot" {
  description = "Skip final snapshot when destroying the database"
  type        = bool
  default     = false
}

variable "db_apply_immediately" {
  description = "Apply changes immediately (vs during maintenance window)"
  type        = bool
  default     = false
}

# Domain and DNS Variables
variable "domain_name" {
  description = "Domain name for the application (e.g., yourdomain.com)"
  type        = string
  default     = ""
}

variable "include_wildcard_cert" {
  description = "Include wildcard subdomain (*.domain.com) in ACM certificate"
  type        = bool
  default     = true
}

variable "create_route53_record" {
  description = "Create Route53 A record for ALB (set to false initially, update after ALB is created)"
  type        = bool
  default     = false
}

variable "create_www_record" {
  description = "Create www subdomain CNAME record"
  type        = bool
  default     = false
}

variable "alb_dns_name" {
  description = "ALB DNS name (get this after ingress creates the ALB)"
  type        = string
  default     = ""
}

variable "alb_zone_id" {
  description = "ALB hosted zone ID (get this after ingress creates the ALB)"
  type        = string
  default     = ""
}
