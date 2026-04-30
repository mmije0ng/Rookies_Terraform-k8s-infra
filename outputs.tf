output "aws_region" {
  description = "AWS 리전"
  value       = var.aws_region
}

output "vpc_id" {
  description = "생성된 VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "퍼블릭 서브넷 ID 목록"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "프라이빗 서브넷 ID 목록"
  value       = aws_subnet.private[*].id
}

output "eks_cluster_name" {
  description = "EKS 클러스터 이름"
  value       = aws_eks_cluster.main.name
}

output "eks_cluster_endpoint" {
  description = "EKS API 서버 엔드포인트"
  value       = aws_eks_cluster.main.endpoint
}

output "eks_cluster_version" {
  description = "EKS 쿠버네티스 버전"
  value       = aws_eks_cluster.main.version
}

output "eks_oidc_provider_arn" {
  description = "EKS OIDC 프로바이더 ARN (IRSA 설정 시 사용)"
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "backend_sa_role_arn" {
  description = "백엔드 서비스 어카운트 IAM 역할 ARN"
  value       = aws_iam_role.backend_sa.arn
}

output "ecr_backend_repository_url" {
  description = "백엔드 ECR 리포지토리 URL"
  value       = aws_ecr_repository.backend.repository_url
}

output "ecr_frontend_repository_url" {
  description = "프론트엔드 ECR 리포지토리 URL"
  value       = aws_ecr_repository.frontend.repository_url
}

output "kubeconfig_command" {
  description = "kubeconfig 업데이트 명령어 (terraform apply 후 실행)"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.main.name}"
}

output "rds_endpoint" {
  description = "RDS 엔드포인트 (DB_URL 구성에 사용)"
  value       = aws_db_instance.main.address
}

output "rds_db_url" {
  description = "Spring Boot DB_URL 환경변수 값"
  value       = "jdbc:mysql://${aws_db_instance.main.address}:3306/${var.db_name}?serverTimezone=Asia/Seoul&characterEncoding=UTF-8"
}

output "s3_bucket_name" {
  description = "S3 버킷 이름 (S3_BUCKET_NAME 환경변수 값)"
  value       = aws_s3_bucket.app.bucket
}
