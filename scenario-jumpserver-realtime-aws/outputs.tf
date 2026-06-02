output "alb_dns_name" {
  description = "Public DNS name of the ALB"
  value       = aws_lb.jump.dns_name
}

output "jumpserver_public_ips" {
  description = "Public IPs of JumpServer nodes"
  value       = aws_instance.jump[*].public_ip
}

output "data_node_public_ip" {
  description = "Public IP of data node"
  value       = aws_instance.data.public_ip
}

output "data_node_private_ip" {
  description = "Private IP of data node"
  value       = aws_instance.data.private_ip
}

output "dns_record_fqdn" {
  description = "DNS record FQDN when Route53 record is created"
  value       = var.create_dns_record ? aws_route53_record.jump[0].fqdn : ""
}

output "iam_role_name" {
  description = "IAM role name when created"
  value       = var.create_iam_role ? aws_iam_role.jump[0].name : ""
}

output "s3_backup_bucket" {
  description = "S3 backup bucket name when enabled"
  value       = var.enable_s3_backup ? local.s3_backup_bucket_name : ""
}
