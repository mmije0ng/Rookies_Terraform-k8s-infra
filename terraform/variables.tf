variable "aws_region" {
  description = "AWS 리전"
  type        = string
  default     = "us-west-1"
}

variable "project_name" {
  description = "프로젝트 이름 (리소스 이름 prefix)"
  type        = string
  default     = "sample-app"
}

variable "environment" {
  description = "배포 환경 (dev / staging / prod)"
  type        = string
  default     = "dev"
}

# ── VPC ────────────────────────────────────────────────────────────────────

variable "vpc_cidr" {
  description = "VPC CIDR 블록"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "퍼블릭 서브넷 CIDR 목록 (ALB 배치)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "프라이빗 서브넷 CIDR 목록 (EKS 노드 배치)"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24"]
}

variable "availability_zones" {
  description = "가용 영역 목록 (서브넷 수와 일치해야 함)"
  type        = list(string)
  default     = ["us-west-1b", "us-west-1c"]
}

# ── EKS ────────────────────────────────────────────────────────────────────

variable "kubernetes_version" {
  description = "EKS 쿠버네티스 버전"
  type        = string
  default     = "1.32"
}

variable "kubernetes_namespace" {
  description = "Kubernetes namespace for the application"
  type        = string
  default     = "sample-app"
}

variable "backend_service_account_name" {
  description = "Kubernetes ServiceAccount name used by the backend Pod"
  type        = string
  default     = "backend-sa"
}
variable "node_instance_type" {
  description = "워커 노드 EC2 인스턴스 타입"
  type        = string
  default     = "t3.medium"
}

variable "node_desired_size" {
  description = "노드 그룹 희망 노드 수"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "노드 그룹 최소 노드 수"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "노드 그룹 최대 노드 수"
  type        = number
  default     = 4
}

# ── RDS ────────────────────────────────────────────────────────────────────

variable "db_instance_class" {
  description = "RDS 인스턴스 타입"
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "초기 생성할 데이터베이스 이름"
  type        = string
  default     = "mydb"
}

variable "db_username" {
  description = "RDS 마스터 사용자명"
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "RDS 마스터 비밀번호 (terraform.tfvars에 직접 입력)"
  type        = string
  sensitive   = true # terraform output 및 로그에 출력되지 않음
}
