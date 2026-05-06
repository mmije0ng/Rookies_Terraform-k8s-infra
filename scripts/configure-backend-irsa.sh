#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-sample-app-eks}"
REGION="${REGION:-us-west-1}"
NAMESPACE="${NAMESPACE:-sample-app}"
SERVICE_ACCOUNT="${SERVICE_ACCOUNT:-backend-sa}"
DEPLOYMENT="${DEPLOYMENT:-backend}"

ROLE_ARN="$(terraform output -raw backend_sa_role_arn)"
BUCKET_NAME="$(terraform output -raw s3_bucket_name)"

echo "Backend IRSA role: ${ROLE_ARN}"
echo "Private S3 bucket: ${BUCKET_NAME}"

aws eks update-kubeconfig --region "${REGION}" --name "${CLUSTER_NAME}"

kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
kubectl create serviceaccount "${SERVICE_ACCOUNT}" -n "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
kubectl annotate serviceaccount "${SERVICE_ACCOUNT}" -n "${NAMESPACE}" "eks.amazonaws.com/role-arn=${ROLE_ARN}" --overwrite

kubectl rollout restart "deployment/${DEPLOYMENT}" -n "${NAMESPACE}"
kubectl rollout status "deployment/${DEPLOYMENT}" -n "${NAMESPACE}"

echo "IRSA environment check:"
kubectl exec "deployment/${DEPLOYMENT}" -n "${NAMESPACE}" -- env | grep -E "AWS_ROLE|AWS_WEB_IDENTITY|AWS_REGION|AWS_DEFAULT_REGION" || true
