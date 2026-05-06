# 배포 가이드

## 전체 흐름 한눈에 보기

```
[최초 1회]
로컬 PC                     GitHub                      AWS
───────────────────────────────────────────────────────────────────────
① 도구 설치
② aws configure (IAM 키 등록)
③ terraform apply ─────────────────────────────────→ VPC, EKS, ECR
                                                      RDS, S3 생성
④ terraform output 확인
                            ⑤ 레포 3개 생성
                            ⑥ 코드 push
                            ⑦ Secrets 등록
⑧ aws eks update-kubeconfig

[이후 매번]
개발자                      GitHub Actions             AWS EKS
───────────────────────────────────────────────────────────────────────
코드 수정 → git push main → 자동 빌드/배포 ──────────→ 롤링 업데이트
```

---

## Phase 1. 로컬 PC 사전 준비 (최초 1회)

### 1-1. 도구 설치 확인

```bash
aws --version          # AWS CLI v2
terraform -version     # >= 1.3.0
kubectl version --client
git --version
docker --version
```

**설치 링크**
- AWS CLI: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
- Terraform: https://developer.hashicorp.com/terraform/install
- kubectl: https://kubernetes.io/docs/tasks/tools/

### 1-2. AWS IAM 사용자 생성 및 CLI 설정

> AWS 콘솔에서 진행

1. IAM → 사용자 → 사용자 생성
2. 권한 정책: `AdministratorAccess` 연결 *(실습용. 운영 환경에서는 최소 권한 원칙 적용)*
3. 액세스 키 생성 (CLI용) → **Access Key ID / Secret Access Key 복사**

```bash
aws configure

# 입력값:
# AWS Access Key ID     : <복사한 키>
# AWS Secret Access Key : <복사한 시크릿>
# Default region name   : ap-northeast-2
# Default output format : json

# 설정 확인
aws sts get-caller-identity
```

---

## Phase 2. Terraform으로 AWS 인프라 전체 생성 (로컬 PC, 최초 1회)

```bash
cd terraform

# terraform.tfvars 생성
cp terraform.tfvars.example terraform.tfvars
```

**terraform.tfvars 에서 반드시 변경할 항목:**

> **서울(ap-northeast-2) 이외 리전 사용 시** → 아래 [리전 변경 가이드](#리전-변경-가이드-서울-이외-리전-사용-시) 참고

```bash
terraform init
terraform plan      # 생성될 리소스 미리 확인
terraform apply     # yes 입력
```

> 약 **20~25분** 소요 (EKS 클러스터 + RDS 생성 시간)

### 생성되는 리소스

| 리소스 | 설명 |
|--------|------|
| VPC, 서브넷, IGW, NAT GW | 네트워크 기반 |
| EKS 클러스터 + 노드 그룹 | t3.medium × 2대 |
| ECR 리포지토리 | backend, frontend 이미지 저장소 |
| IAM 역할 (IRSA) | 백엔드 Pod의 S3 접근용 |
| RDS MySQL 8.0 | db.t3.micro, 프라이빗 서브넷 배치 |
| S3 버킷 | 파일 업로드/다운로드용, 퍼블릭 접근 차단 |

### terraform output 값 확인 및 기록

```bash
terraform output

# GitHub Secrets 등록에 필요한 값들
terraform output -raw eks_cluster_name
terraform output -raw ecr_backend_repository_url
terraform output -raw ecr_frontend_repository_url
terraform output -raw backend_sa_role_arn
terraform output -raw rds_db_url          # DB_URL 값 그대로 사용
terraform output -raw s3_bucket_name      # S3_BUCKET_NAME 값 그대로 사용
```

---

## Phase 3. GitHub 레포 생성 및 코드 Push (GitHub + 로컬 PC, 최초 1회)

### 3-1. GitHub에서 레포 3개 생성

> GitHub → New repository

| 레포 이름 | 올릴 코드 |
|-----------|----------|
| `sample-app-infra` | `terraform/` 폴더 전체 |
| `sample-app-back` | `sample-app/back/` 폴더 전체 |
| `sample-app-front` | `sample-app/front/` 폴더 전체 |

### 3-2. 각 레포에 코드 Push

```bash
# ── infra 레포 ──────────────────────────────────────
cd terraform
git init
git add .
git commit -m "init: terraform EKS infra"
git remote add origin https://github.com/<계정>/sample-app-infra.git
git push -u origin main

# ── back 레포 ────────────────────────────────────────
cd 03_exmplecode/sample-app/back
# (이미 .git 있으므로 remote만 추가 또는 변경)
git remote add origin https://github.com/<계정>/sample-app-back.git
git add .
git commit -m "feat: add EKS deploy workflow"
git push -u origin main

# ── front 레포 ───────────────────────────────────────
cd 03_exmplecode/sample-app/front
git remote add origin https://github.com/<계정>/sample-app-front.git
git add .
git commit -m "feat: add EKS deploy workflow"
git push -u origin main
```

> infra 레포에 `terraform.tfvars` 가 포함되지 않도록 주의하세요.  
> (비밀번호가 포함됨 → `.gitignore`에 `terraform.tfvars` 추가 권장)

### 3-3. GitHub Secrets 등록

> 각 레포 → Settings → Secrets and variables → Actions → New repository secret

Secrets에 입력할 값을 먼저 확인합니다.

```bash
cd terraform

terraform output -raw eks_cluster_name
terraform output -raw ecr_backend_repository_url
terraform output -raw ecr_frontend_repository_url
terraform output -raw backend_sa_role_arn
terraform output -raw s3_bucket_name
```

#### sample-app-back 레포 (6개)

| Secret 이름 | 값 |
|-------------|-----|
| `AWS_ACCESS_KEY_ID` | IAM 액세스 키 |
| `AWS_SECRET_ACCESS_KEY` | IAM 시크릿 키 |
| `ECR_BACKEND_URI` | `terraform output -raw ecr_backend_repository_url` |
| `EKS_CLUSTER_NAME` | `terraform output -raw eks_cluster_name` |
| `BACKEND_SA_ROLE_ARN` | `terraform output -raw backend_sa_role_arn` |
| `S3_BUCKET_NAME` | `terraform output -raw s3_bucket_name` |

#### sample-app-front 레포 (4개)

| Secret 이름 | 값 |
|-------------|-----|
| `AWS_ACCESS_KEY_ID` | IAM 액세스 키 |
| `AWS_SECRET_ACCESS_KEY` | IAM 시크릿 키 |
| `ECR_FRONTEND_URI` | `terraform output -raw ecr_frontend_repository_url` |
| `EKS_CLUSTER_NAME` | `terraform output -raw eks_cluster_name` |

---

## Phase 4. kubectl 로컬 설정 (로컬 PC, 최초 1회)

```bash
cd terraform

aws eks update-kubeconfig \
  --region ap-northeast-2 \
  --name $(terraform output -raw eks_cluster_name)

# 노드 Ready 상태 확인
kubectl get nodes
```

---

## Phase 5. 최초 배포 (GitHub Push)

> 3-2에서 이미 push했다면 Actions가 자동으로 실행됩니다.  
> 아직 안 했다면 아래 순서로 진행하세요.

### 5-1. 백엔드 먼저 배포

```bash
cd 03_exmplecode/sample-app/back
git add .
git commit -m "feat: add EKS deploy workflow"
git push origin main
```

GitHub → sample-app-back → Actions 탭에서 진행 상황 확인 (약 5~7분)

### 5-2. 백엔드 배포 확인 (로컬 PC)

```bash
kubectl get pods -n sample-app
# backend-xxxxxxxxx-xxxxx   1/1   Running   0   2m

kubectl get svc -n sample-app
# backend-service   ClusterIP   10.100.x.x   <none>   8080/TCP
```

### 5-3. 백엔드 확인 후 프론트엔드 배포

```bash
cd 03_exmplecode/sample-app/front
git add .
git commit -m "feat: add EKS deploy workflow"
git push origin main
```

GitHub → sample-app-front → Actions 탭에서 진행 상황 확인 (약 3~5분)

### 5-4. 접속 URL 확인 (로컬 PC)

```bash
# NLB 생성에 1~2분 소요 → <pending> 이면 잠시 후 재시도
kubectl get svc frontend-service -n sample-app -w
```

`http://<EXTERNAL-IP>` 브라우저 접속

---

## Phase 6. 이후 일상 배포

코드 수정 후 `git push origin main` 만 하면 자동 배포됩니다.

```bash
git add .
git commit -m "feat: 수정 내용"
git push origin main
# → GitHub Actions 자동 실행 → EKS 롤링 업데이트 (무중단)
```

---

## 장애 대응 명령어 (로컬 PC)

```bash
# 전체 리소스 상태
kubectl get all -n sample-app

# Pod 로그
kubectl logs -l app=backend  -n sample-app --tail=100
kubectl logs -l app=frontend -n sample-app --tail=100

# Pod 상세 정보 (CrashLoopBackOff 등 에러 원인 확인)
kubectl describe pod -l app=backend -n sample-app

# 이전 버전으로 롤백
kubectl rollout undo deployment/backend  -n sample-app
kubectl rollout undo deployment/frontend -n sample-app
```

---

## 인프라 삭제 (비용 절감)

```bash
# 1. K8s 리소스 먼저 삭제 (NLB가 남으면 VPC 삭제 실패)
kubectl delete namespace sample-app

# 2. AWS 인프라 삭제
cd terraform
terraform destroy
```

---

## 리전 변경 가이드 (서울 이외 리전 사용 시)

기본값은 `ap-northeast-2` (서울)입니다. 다른 리전 사용 시 아래 **5곳**을 변경하세요.

### 변경할 파일 목록

| # | 파일 | 변경 항목 |
|---|------|----------|
| 1 | `terraform/terraform.tfvars` | `aws_region`, `availability_zones` |
| 2 | `sample-app/back/.github/workflows/deploy-eks.yml` | `AWS_REGION` |
| 3 | `sample-app/front/.github/workflows/deploy-eks.yml` | `AWS_REGION` |
| 4 | `sample-app/back/src/main/resources/application.yml` | `cloud.aws.region` |
| 5 | `docs/DEPLOY.md` | 문서 내 리전 문자열 (선택) |

---

### 1. `terraform/terraform.tfvars`

```hcl
aws_region = "us-east-1"   # ← 변경

# availability_zones 도 해당 리전 AZ로 반드시 변경
availability_zones = ["us-east-1a", "us-east-1b"]
```

> `terraform.tfvars` 하나로 Terraform 리소스 전체에 자동 반영됩니다.

---

### 2. `sample-app/back/.github/workflows/deploy-eks.yml`

```yaml
env:
  AWS_REGION: us-east-1   # ← 변경
```

---

### 3. `sample-app/front/.github/workflows/deploy-eks.yml`

```yaml
env:
  AWS_REGION: us-east-1   # ← 변경
```

---

### 4. `sample-app/back/src/main/resources/application.yml`

```yaml
cloud:
  aws:
    region: us-east-1     # ← 변경 (S3 SDK가 사용하는 리전)
```

---

### 주요 리전별 AZ 참고

| 리전 | 위치 | availability_zones |
|------|------|--------------------|
| `ap-northeast-2` | 서울 | `["ap-northeast-2a", "ap-northeast-2c"]` |
| `ap-northeast-1` | 도쿄 | `["ap-northeast-1a", "ap-northeast-1c"]` |
| `ap-southeast-1` | 싱가포르 | `["ap-southeast-1a", "ap-southeast-1b"]` |
| `us-east-1` | 버지니아 | `["us-east-1a", "us-east-1b"]` |
| `us-west-2` | 오레곤 | `["us-west-2a", "us-west-2b"]` |
| `eu-west-1` | 아일랜드 | `["eu-west-1a", "eu-west-1b"]` |

> AZ 목록은 AWS 콘솔 → EC2 → 가용 영역에서 확인할 수 있습니다.

### 변경 체크리스트

```
□ terraform/terraform.tfvars
    aws_region         = "<내 리전>"
    availability_zones = ["<AZ-1>", "<AZ-2>"]

□ sample-app/back/.github/workflows/deploy-eks.yml
    AWS_REGION: <내 리전>

□ sample-app/front/.github/workflows/deploy-eks.yml
    AWS_REGION: <내 리전>

□ sample-app/back/src/main/resources/application.yml
    region: <내 리전>
```
