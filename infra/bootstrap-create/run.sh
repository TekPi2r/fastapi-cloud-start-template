#!/usr/bin/env bash
set -euo pipefail

# Simple runner for bootstrap-state (LOCAL STATE)
# Creates only S3 bucket + DynamoDB lock table (no backend here)

CMD="${1:-help}"

AWS_REGION="${AWS_REGION:-eu-west-3}"

# Required
BUCKET_NAME="${BUCKET_NAME:-}"
DYNAMO_TABLE="${DYNAMO_TABLE:-terraform-locks}"
NAME_PREFIX="${NAME_PREFIX:-fastapi}"
ENVIRONMENT="${ENVIRONMENT:-bootstrap}"

usage() {
  cat <<EOF
Usage:
  (env) AWS_REGION=eu-west-3 BUCKET_NAME=<unique-s3-bucket> ./run.sh <check|init|plan|apply|outputs|destroy>

Required env:
  BUCKET_NAME               # must be globally unique

Optional env:
  DYNAMO_TABLE=terraform-locks
  NAME_PREFIX=fastapi
  ENVIRONMENT=bootstrap

Examples:
  export AWS_REGION="eu-west-3"
  export BUCKET_NAME="tfstate-yourhandle-euw3"

  ./run.sh check
  ./run.sh init
  ./run.sh plan
  ./run.sh apply
  ./run.sh outputs
  ./run.sh destroy   # careful
EOF
}

require() { command -v "$1" >/dev/null 2>&1 || { echo "Missing: $1"; exit 1; }; }

preflight() {
  require aws
  require terraform
  if [[ -z "${BUCKET_NAME}" ]]; then
    echo "BUCKET_NAME is required (globally unique S3 bucket)"; exit 1
  fi
  echo "AWS_REGION=${AWS_REGION} BUCKET_NAME=$BUCKET_NAME"
  aws sts get-caller-identity >/dev/null
}

init_cmd() {
  terraform init
}

plan_cmd() {
  terraform validate
  terraform plan \
    -var "aws_region=${AWS_REGION}" \
    -var "bucket_name=${BUCKET_NAME}" \
    -var "dynamodb_table_name=${DYNAMO_TABLE}" \
    -var "name_prefix=${NAME_PREFIX}" \
    -var "environment=${ENVIRONMENT}"
}

apply_cmd() {
  terraform apply -auto-approve \
    -var "aws_region=${AWS_REGION}" \
    -var "bucket_name=${BUCKET_NAME}" \
    -var "dynamodb_table_name=${DYNAMO_TABLE}" \
    -var "name_prefix=${NAME_PREFIX}" \
    -var "environment=${ENVIRONMENT}"
}

destroy_cmd() {
  terraform destroy -auto-approve \
    -var "aws_region=${AWS_REGION}" \
    -var "bucket_name=${BUCKET_NAME}" \
    -var "dynamodb_table_name=${DYNAMO_TABLE}" \
    -var "name_prefix=${NAME_PREFIX}" \
    -var "environment=${ENVIRONMENT}"
}

case "${CMD}" in
  help|-h|--help) usage ;;
  check)          preflight ;;
  init)           preflight; init_cmd ;;
  plan)           preflight; init_cmd; plan_cmd ;;
  apply)          preflight; init_cmd; apply_cmd ;;
  outputs)        terraform output || true ;;
  destroy)        preflight; init_cmd; destroy_cmd ;;
  *)              usage; exit 1 ;;
esac
