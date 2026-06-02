variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "aws_key_name" {
  description = "Existing AWS EC2 key pair name"
  type        = string
}

variable "project_name" {
  description = "Prefix for resource names"
  type        = string
  default     = "jump-realtime"
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
  default     = "10.40.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs"
  type        = list(string)
  default     = ["10.40.1.0/24", "10.40.2.0/24"]
}

variable "admin_cidr" {
  description = "CIDR allowed for SSH access"
  type        = string
  default     = "0.0.0.0/0"
}

variable "jump_node_count" {
  description = "Number of JumpServer nodes"
  type        = number
  default     = 2

  validation {
    condition     = var.jump_node_count == 2
    error_message = "This scenario expects exactly 2 JumpServer nodes."
  }
}

variable "jump_instance_type" {
  description = "JumpServer instance type"
  type        = string
  default     = "t3.small"
}

variable "data_instance_type" {
  description = "DB/Redis instance type"
  type        = string
  default     = "t3.small"
}

variable "data_volume_size_gb" {
  description = "Data node root volume size (GB)"
  type        = number
  default     = 40
}

variable "jump_volume_size_gb" {
  description = "JumpServer app node root volume size (GB)"
  type        = number
  default     = 50
}

variable "postgres_db" {
  description = "JumpServer PostgreSQL DB name"
  type        = string
  default     = "jumpserver"
}

variable "postgres_user" {
  description = "JumpServer PostgreSQL username"
  type        = string
  default     = "postgres"
}

variable "postgres_password" {
  description = "JumpServer PostgreSQL password"
  type        = string
  sensitive   = true
}

variable "redis_password" {
  description = "Redis password"
  type        = string
  sensitive   = true
}

variable "storagebox_user" {
  description = "Storage Box username"
  type        = string
  default     = ""
}

variable "storagebox_password" {
  description = "Storage Box password"
  type        = string
  sensitive   = true
  default     = ""
}

variable "storagebox_host" {
  description = "Storage Box host"
  type        = string
  default     = ""
}

variable "storagebox_remote_path" {
  description = "Storage Box remote path (ex: /backup/)"
  type        = string
  default     = "/backup/"
}

variable "create_dns_record" {
  description = "Whether to create a Route53 record for the ALB"
  type        = bool
  default     = false
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID (required when create_dns_record is true)"
  type        = string
  default     = ""
}

variable "dns_record_name" {
  description = "DNS record name (e.g. jump.example.com)"
  type        = string
  default     = ""
}
variable "create_iam_role" {
  description = "Whether to create an IAM role and instance profile for EC2"
  type        = bool
  default     = true
}

variable "iam_role_name" {
  description = "Custom IAM role name (optional)"
  type        = string
  default     = ""
}

variable "attach_ssm_policy" {
  description = "Attach AmazonSSMManagedInstanceCore policy"
  type        = bool
  default     = true
}

variable "attach_cloudwatch_policy" {
  description = "Attach CloudWatchAgentServerPolicy"
  type        = bool
  default     = false
}

variable "enable_s3_backup" {
  description = "Enable S3 backups from the data node"
  type        = bool
  default     = false
}

variable "create_s3_backup_bucket" {
  description = "Create an S3 bucket for backups (requires s3_backup_bucket_name)"
  type        = bool
  default     = false
}

variable "s3_backup_bucket_name" {
  description = "S3 bucket name for backups"
  type        = string
  default     = ""

  validation {
    condition     = (var.create_s3_backup_bucket == false && var.enable_s3_backup == false) || length(var.s3_backup_bucket_name) > 0
    error_message = "s3_backup_bucket_name must be set when create_s3_backup_bucket or enable_s3_backup is true."
  }
}

variable "s3_backup_prefix" {
  description = "Prefix path in the S3 bucket (ex: jumpserver/)"
  type        = string
  default     = "jumpserver/"
}

variable "s3_backup_cron" {
  description = "Cron schedule for S3 backups (UTC)"
  type        = string
  default     = "0 * * * *"
}
