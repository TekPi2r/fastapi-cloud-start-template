#!/usr/bin/env bash
set -euo pipefail

# ================================
# 🧰 Terraform Bootstrap Runner
# - Pre-flight checks
# - Clean checks (ensure no leftovers)
# - Safe & repeatable commands
# ================================

# -------- Defaults (override via env) --------
AWS_PROFILE="${AWS_PROFILE:-bootstrap}"
AWS_REGION="${AWS_REGION:-eu-west-3}"
BUCKET_NAME="${BUCKET_NAME:-}"            # required
DDB_TABLE="${DDB_TABLE:-terraform-locks}" # matches variables.tf
SSE_KMS_KEY_ARN="${SSE_KMS_KEY_ARN:-}"    # optional

# -------- Helpers --------
usage() {
  cat <<EOF
Usage:
  BUCKET_NAME=<unique-s3-bucket> [AWS_PROFILE=bootstrap] [AWS_REGION=eu-west-3] $0 <check|check-clean|init|plan|apply|outputs|destroy>

Examples:
  export BUCKET_NAME="tfstate-yourhandle-euw3"
  export AWS_PROFILE="bootstrap"
  export AWS_REGION="eu-west-3"

  $0 check
  $0 check-clean
  $0 init
  $0 plan
  $0 apply
  $0 outputs
  $0 destroy   # (careful)

Notes:
- BUCKET_NAME must be globally unique (S3 requirement).
- Region/profile are passed to Terraform via variables.
EOF
}

has_cmd() { command -v "$1" >/dev/null 2>&1; }

validate_bucket_name() {
  local name="$1"
  [[ ${#name} -ge 3 && ${#name} -le 63 ]] || return 1
  [[ "$name" =~ ^[a-z0-9][a-z0-9.-]*[a-z0-9]$ ]] || return 1
  [[ "$name" != *".."* ]] || return 1
  [[ "$name" != -* && "$name" != *- ]] || return 1
  if [[ "$name" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then return 1; fi
  return 0
}

preflight() {
  echo "🔎 Pre-flight checks..."
  has_cmd aws || { echo "❌ AWS CLI not found"; exit 1; }
  has_cmd terraform || { echo "❌ Terraform not found"; exit 1; }

  echo "➡️  AWS profile: ${AWS_PROFILE}"
  echo "➡️  AWS region : ${AWS_REGION}"

  aws sts get-caller-identity --profile "${AWS_PROFILE}" >/dev/null \
    || { echo "❌ AWS profile '${AWS_PROFILE}' not authenticated"; exit 1; }

  if [[ -z "${BUCKET_NAME}" ]]; then
    echo "❌ BUCKET_NAME is required (e.g., tfstate-yourhandle-euw3)"; exit 1;
  fi
  if ! validate_bucket_name "${BUCKET_NAME}"; then
    echo "❌ BUCKET_NAME '${BUCKET_NAME}' is not a valid S3 bucket name"; exit 1;
  fi

  echo "✅ Checks OK"
}

check_clean() {
  echo "🧼 Checking cloud cleanliness (no leftovers)..."
  local bucket_exists=0
  local table_exists=0
  local bucket_state="absent"  # absent|owned|exists_other

  # Check S3 bucket existence
  if aws s3api head-bucket --bucket "${BUCKET_NAME}" --profile "${AWS_PROFILE}" 2>/dev/null; then
    bucket_exists=1
  fi

  if out=$(aws s3api head-bucket --bucket "${BUCKET_NAME}" --profile "${AWS_PROFILE}" 2>&1); then
    bucket_exists=1; bucket_state="owned"
  else
    # Si 403/AccessDenied -> il existe mais pas à nous
    if echo "$out" | grep -qiE 'Forbidden|AccessDenied'; then
      bucket_exists=1; bucket_state="exists_other"
    fi
  fi

  # Check DynamoDB table existence
  if aws dynamodb describe-table --table-name "${DDB_TABLE}" --profile "${AWS_PROFILE}" >/dev/null 2>&1; then
    table_exists=1
  fi

  if [[ $bucket_exists -eq 0 && $table_exists -eq 0 ]]; then
    echo "✅ Clean: no existing S3 bucket '${BUCKET_NAME}' or DynamoDB table '${DDB_TABLE}'."
    return 0
  fi

  echo "⚠️  Not clean:"
  [[ $bucket_exists -eq 1 ]] && echo "   - S3 bucket exists: ${BUCKET_NAME} (delete it or choose a different BUCKET_NAME)"
  if [[ $bucket_exists -eq 1 ]]; then
    if [[ "$bucket_state" == "owned" ]]; then
      echo "   - S3 bucket exists (owned): ${BUCKET_NAME} (delete it or choose a different BUCKET_NAME)"
    else
      echo "   - S3 bucket exists (NOT owned): ${BUCKET_NAME} (choose a different BUCKET_NAME)"
    fi
  fi
  [[ $table_exists  -eq 1 ]] && echo "   - DynamoDB table exists: ${DDB_TABLE} (delete it or change table name in Terraform)"
  return 1
}

local_clean() {
  echo "⚠️  WARNING: This will DELETE all local Terraform state & lock files in this folder."
  read -p "Type 'yes' to confirm: " confirm
  if [ "$confirm" != "yes" ]; then
    echo "❌ Aborted."
    exit 1
  fi

  rm -rf \
    .terraform \
    .terraform.lock.hcl \
    *.tfstate \
    *.tfstate.* \
    crash.log \
    override.tf \
    override.tf.json \
    *_override.tf \
    *_override.tf.json

  echo "🧹 Local Terraform files removed."
}

cmd="${1:-}"; [[ -z "$cmd" ]] && { usage; exit 1; }

case "$cmd" in
  check)
    preflight
    ;;

  check-clean)
    preflight
    check_clean
    ;;

  init)
    preflight
    terraform init
    ;;

  plan)
    preflight
    terraform fmt -check
    terraform validate
    terraform plan \
      -var "aws_region=${AWS_REGION}" \
      -var "aws_profile=${AWS_PROFILE}" \
      -var "bucket_name=${BUCKET_NAME}" \
      -var "dynamodb_table_name=${DDB_TABLE}" \
      -var "sse_kms_key_arn=${SSE_KMS_KEY_ARN}"
    ;;

  apply)
    preflight
    terraform fmt -check
    terraform validate
    terraform apply -auto-approve \
      -var "aws_region=${AWS_REGION}" \
      -var "aws_profile=${AWS_PROFILE}" \
      -var "bucket_name=${BUCKET_NAME}" \
      -var "dynamodb_table_name=${DDB_TABLE}" \
      -var "sse_kms_key_arn=${SSE_KMS_KEY_ARN}"
    echo "📤 Outputs:"
    terraform output
    ;;

  outputs)
    terraform output
    ;;

  local-clean) local_clean ;;

  destroy)
    preflight
    echo "⚠️ Destroying resources created by bootstrap..."
    terraform destroy -auto-approve \
      -var "aws_region=${AWS_REGION}" \
      -var "aws_profile=${AWS_PROFILE}" \
      -var "bucket_name=${BUCKET_NAME}" \
      -var "dynamodb_table_name=${DDB_TABLE}" \
      -var "sse_kms_key_arn=${SSE_KMS_KEY_ARN}"
    ;;

  *)
    usage; exit 1;;
esac
