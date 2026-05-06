output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_region" {
  description = "AWS region"
  value       = var.region
}

output "github_deploy_role_arn" {
  description = "IAM role ARN for GitHub Actions"
  value       = aws_iam_role.github_deploy.arn
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}
