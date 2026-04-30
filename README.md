# Terraform AWS Infrastructure

이 프로젝트는 Terraform으로 AWS 인프라를 자동 구성하고, EKS 기반 애플리케이션 실행 환경을 생성하는 프로젝트입니다.

구성 대상은 VPC, public/private subnet, NAT gateway, EKS cluster/node group, ECR, RDS MySQL, S3 bucket, IAM role 및 IRSA입니다.

## Architecture

```text
Developer PC
  |
  | terraform apply / kubectl / docker push
  v
AWS
  |
  +-- VPC: 10.0.0.0/16
      |
      +-- Public Subnets: 10.0.1.0/24, 10.0.2.0/24
      |   |
      |   +-- Internet Gateway
      |   +-- NAT Gateway
      |
      +-- Private Subnets: 10.0.10.0/24, 10.0.20.0/24
          |
          +-- EKS Managed Node Group
          |   |
          |   +-- Backend Pod
          |       |
          |       +-- RDS MySQL: 3306
          |       +-- S3 Bucket via IRSA
          |
          +-- RDS MySQL
```

## Communication Flow

### Backend to RDS

RDS는 private subnet에 배치되고 public access가 꺼져 있습니다.

```hcl
publicly_accessible = false
```

RDS security group은 private subnet CIDR에서 들어오는 MySQL 트래픽만 허용합니다.

```text
Allowed inbound:
10.0.10.0/24 -> TCP 3306
10.0.20.0/24 -> TCP 3306
```

따라서 로컬 PC에서 RDS endpoint로 직접 접속하면 timeout이 나는 것이 정상입니다. 백엔드가 EKS private node 위에서 실행될 때 RDS에 접근할 수 있습니다.

### Backend to S3

백엔드 Pod는 IRSA 구성을 통해 S3 접근용 IAM role을 사용할 수 있습니다.

```text
ServiceAccount: system:serviceaccount:sample-app:backend-sa
IAM Role: sample-app-backend-sa-role
```

현재 inline policy는 S3 접근을 `Resource = "*"`로 허용합니다. 실서비스에서는 특정 bucket ARN으로 제한하는 것이 좋습니다.

### EKS to ECR

백엔드와 프론트엔드 이미지는 ECR repository에 저장됩니다.

```text
sample-app/backend
sample-app/frontend
```

EKS node role에는 ECR read-only 정책이 연결되어 있어 node가 ECR에서 이미지를 pull 할 수 있습니다.

## Main Resources

| Area | Resource |
| --- | --- |
| Network | VPC, public/private subnets, internet gateway, NAT gateway, route tables |
| Compute | EKS cluster, managed node group |
| Registry | ECR repositories for backend and frontend |
| Database | RDS MySQL |
| Storage | S3 bucket |
| IAM | EKS cluster role, node role, backend service account role, OIDC provider |

## Current Defaults

| Variable | Default |
| --- | --- |
| `aws_region` | `us-west-1` |
| `project_name` | `sample-app` |
| `environment` | `dev` |
| `db_name` | `mydb` |
| `db_username` | `admin` |
| `kubernetes_version` | `1.32` |
| `node_instance_type` | `t3.medium` |

`db_password`는 기본값이 없습니다. `terraform plan` 또는 `terraform apply` 실행 시 직접 입력하거나 `-var`로 전달해야 합니다.

```powershell
terraform apply -var 'db_password=<db-password>'
```

## Usage

초기화:

```powershell
terraform init
```

변경 계획 확인:

```powershell
terraform plan -var 'db_password=<db-password>'
```

적용:

```powershell
terraform apply -var 'db_password=<db-password>'
```

출력 확인:

```powershell
terraform output
terraform output -raw rds_db_url
terraform output -raw s3_bucket_name
```

EKS kubeconfig 설정:

```powershell
aws eks update-kubeconfig --region us-west-1 --name sample-app-eks
```

## Backend Environment Values

백엔드 애플리케이션에는 보통 아래 값이 필요합니다.

```text
DB_URL=<terraform output rds_db_url>
DB_USERNAME=admin
DB_PASSWORD=<terraform apply에 사용한 db_password>
S3_BUCKET_NAME=<terraform output s3_bucket_name>
AWS_REGION=us-west-1
```

현재 구성에서 생성되는 S3 bucket 이름은 다음 형식입니다.

```text
sample-app-dev-files-<aws-account-id>-mj
```

## DB Connectivity Check

로컬 PC에서 RDS로 직접 접속하는 것은 기본 구성상 차단됩니다. EKS 내부에서 확인하려면 임시 Pod를 사용합니다.

```powershell
kubectl run mysql-test --rm -it --image=mysql:8 --restart=Never -- `
  mysql -h <rds-endpoint> -u admin -p
```

비밀번호는 `terraform apply`에 사용한 `db_password` 값을 입력합니다.

## Git Safety

아래 파일은 Git에 올리면 안 됩니다.

```text
terraform.tfstate
terraform.tfstate.backup
*.tfvars
.terraform/
```

현재 `.gitignore`는 위 Terraform local state와 민감값 파일을 제외하도록 구성되어 있습니다. `terraform.tfstate`에는 RDS 비밀번호, AWS 리소스 ID, ARN 등이 들어갈 수 있으므로 공개 저장소에 커밋하지 마세요.
