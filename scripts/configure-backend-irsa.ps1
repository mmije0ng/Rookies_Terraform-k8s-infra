param(
  [string]$ClusterName = "sample-app-eks",
  [string]$Region = "us-west-1",
  [string]$Namespace = "sample-app",
  [string]$ServiceAccount = "backend-sa",
  [string]$Deployment = "backend"
)

$ErrorActionPreference = "Stop"

$roleArn = terraform output -raw backend_sa_role_arn
$bucketName = terraform output -raw s3_bucket_name

Write-Host "Backend IRSA role: $roleArn"
Write-Host "Private S3 bucket: $bucketName"

aws eks update-kubeconfig --region $Region --name $ClusterName

kubectl create namespace $Namespace --dry-run=client -o yaml | kubectl apply -f -
kubectl create serviceaccount $ServiceAccount -n $Namespace --dry-run=client -o yaml | kubectl apply -f -
kubectl annotate serviceaccount $ServiceAccount -n $Namespace "eks.amazonaws.com/role-arn=$roleArn" --overwrite

kubectl rollout restart "deployment/$Deployment" -n $Namespace
kubectl rollout status "deployment/$Deployment" -n $Namespace

Write-Host "IRSA environment check:"
kubectl exec "deployment/$Deployment" -n $Namespace -- env | Select-String "AWS_ROLE|AWS_WEB_IDENTITY|AWS_REGION|AWS_DEFAULT_REGION"
