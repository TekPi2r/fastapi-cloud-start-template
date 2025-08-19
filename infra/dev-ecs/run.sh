#!/usr/bin/env bash
set -euo pipefail

CMD="${1:-help}"

AWS_REGION="${AWS_REGION:-eu-west-3}"

TF_BACKEND_BUCKET="${TF_BACKEND_BUCKET:-}"
TF_BACKEND_DYNAMO_TABLE="${TF_BACKEND_DYNAMO_TABLE:-}"

NAME_PREFIX="${NAME_PREFIX:-fastapi}"
ENVIRONMENT="${ENVIRONMENT:-dev}"

IMAGE_TAG="${IMAGE_TAG:-dev}"
DESIRED_COUNT="${DESIRED_COUNT:-1}"
TASK_CPU="${TASK_CPU:-256}"
TASK_MEMORY="${TASK_MEMORY:-512}"
VPC_ID="${VPC_ID:-}"
PUBLIC_SUBNET_IDS="${PUBLIC_SUBNET_IDS:-}" # comma-separated, optional
ACM_CERT_ARN="${ACM_CERT_ARN:-}"          # optional
LOG_GROUP_NAME="${LOG_GROUP_NAME:-/fastapi/dev}"

usage() {
  cat <<EOF
Usage:
  (env) $0 <check|init|plan|apply|outputs|destroy|ecr-login|ecr-push|url>

Required env:
  TF_BACKEND_BUCKET, TF_BACKEND_DYNAMO_TABLE
Optional env:
  NAME_PREFIX=${NAME_PREFIX}
  ENVIRONMENT=${ENVIRONMENT}
  IMAGE_TAG=${IMAGE_TAG}
  DESIRED_COUNT=${DESIRED_COUNT}
  TASK_CPU=${TASK_CPU}  TASK_MEMORY=${TASK_MEMORY}
  VPC_ID=${VPC_ID}
  PUBLIC_SUBNET_IDS="subnet-aaa,subnet-bbb"
  ACM_CERT_ARN=${ACM_CERT_ARN}
  LOG_GROUP_NAME=${LOG_GROUP_NAME}
EOF
}

require() { command -v "$1" >/dev/null 2>&1 || { echo "Missing: $1"; exit 1; }; }

preflight() {
  require aws
  require terraform
  [[ -n "$TF_BACKEND_BUCKET" ]] || { echo "TF_BACKEND_BUCKET required"; exit 1; }
  [[ -n "$TF_BACKEND_DYNAMO_TABLE" ]] || { echo "TF_BACKEND_DYNAMO_TABLE required"; exit 1; }
  aws sts get-caller-identity >/dev/null
  echo "AWS_REGION=$AWS_REGION TF_BACKEND_BUCKET=$TF_BACKEND_BUCKET TF_BACKEND_DYNAMO_TABLE=$TF_BACKEND_DYNAMO_TABLE"
}

init_backend() {
  terraform init \
    -backend-config="bucket=${TF_BACKEND_BUCKET}" \
    -backend-config="key=dev-ecs/terraform.tfstate" \
    -backend-config="region=${AWS_REGION}" \
    -backend-config="dynamodb_table=${TF_BACKEND_DYNAMO_TABLE}" \
    -backend-config="encrypt=true"
}

tf_vars() {
  local extra=""
  if [[ -n "$VPC_ID" ]]; then extra="$extra -var vpc_id=${VPC_ID}"; fi
  if [[ -n "$PUBLIC_SUBNET_IDS" ]]; then
    IFS=',' read -r -a arr <<< "$PUBLIC_SUBNET_IDS"
    local list="["
    for s in "${arr[@]}"; do list="$list\"$s\","; done
    list="${list%,}]"
    extra="$extra -var public_subnet_ids=${list}"
  fi
  if [[ -n "$ACM_CERT_ARN" ]]; then extra="$extra -var acm_certificate_arn=${ACM_CERT_ARN}"; fi
  if [[ -n "$LOG_GROUP_NAME" ]]; then extra="$extra -var log_group_name=${LOG_GROUP_NAME}"; fi

  echo "-var aws_region=${AWS_REGION} \
        -var name_prefix=${NAME_PREFIX} \
        -var environment=${ENVIRONMENT} \
        -var image_tag=${IMAGE_TAG} \
        -var desired_count=${DESIRED_COUNT} \
        -var task_cpu=${TASK_CPU} \
        -var task_memory=${TASK_MEMORY} \
        ${extra}"
}

plan_cmd() {
  terraform fmt -recursive >/dev/null || true
  terraform validate
  # shellcheck disable=SC2046
  set +e
  terraform plan -input=false -no-color -detailed-exitcode -out=tfplan $(tf_vars)
  ec=$?
  set -e

  if [ "$ec" -eq 1 ]; then
    echo "Terraform plan failed" >&2
    exit 1
  elif [ "$ec" -eq 2 ]; then
    echo "Terraform plan found changes (expected in deploy)."
  else
    echo "No changes."
  fi
}

apply_cmd() {
  # shellcheck disable=SC2046
  terraform apply -input=false -auto-approve tfplan $(tf_vars) || terraform apply -input=false -auto-approve $(tf_vars)
}

destroy_cmd() {
  # shellcheck disable=SC2046
  terraform destroy -auto-approve $(tf_vars)
}

outputs_cmd() { terraform output || true; }

ecr_login_cmd() {
  local REPO_URL
  REPO_URL="$(terraform output -raw ecr_repo_url 2>/dev/null || true)"
  if [[ -z "$REPO_URL" ]]; then
    local ACCOUNT_ID="${AWS_ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text)}"
    REPO_URL="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${NAME_PREFIX}-${ENVIRONMENT}-ecr"
  fi
  aws ecr get-login-password --region "$AWS_REGION" \
    | docker login --username AWS --password-stdin "${REPO_URL%/*}"
}

ecr_push_cmd() {
  require docker
  ecr_login_cmd
  local REPO_URL
  REPO_URL="$(terraform output -raw ecr_repo_url 2>/dev/null || true)"
  if [[ -z "$REPO_URL" ]]; then
    local ACCOUNT_ID="${AWS_ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text)}"
    REPO_URL="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${NAME_PREFIX}-${ENVIRONMENT}-ecr"
  fi
  docker buildx create --use >/dev/null 2>&1 || true
  docker buildx build --platform linux/amd64 -t "${REPO_URL}:${IMAGE_TAG}" --push .
}

url_cmd() {
  local DNS
  DNS="$(terraform output -raw alb_dns_name)"
  echo "ALB URL: http://${DNS}/"
}

case "${CMD}" in
  check)       preflight ;;
  init)        preflight; init_backend ;;
  plan)        preflight; init_backend; plan_cmd ;;
  apply)       preflight; init_backend; apply_cmd ;;
  outputs)     outputs_cmd ;;
  destroy)     preflight; init_backend; destroy_cmd ;;
  ecr-login)   preflight; ecr_login_cmd ;;
  ecr-push)    preflight; ecr_push_cmd ;;
  url)         url_cmd ;;
  *)           usage; exit 1 ;;
esac
