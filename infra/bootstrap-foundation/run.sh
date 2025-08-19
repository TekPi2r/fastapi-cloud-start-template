#!/usr/bin/env bash
set -euo pipefail

# bootstrap-foundation: OIDC provider + CI role (least privilege)
# Uses remote backend (S3 + Dynamo) created by bootstrap-state

CMD="${1:-help}"

AWS_REGION="${AWS_REGION:-eu-west-3}"

TF_BACKEND_BUCKET="${TF_BACKEND_BUCKET:-}"
TF_BACKEND_DYNAMO_TABLE="${TF_BACKEND_DYNAMO_TABLE:-}"

AWS_REGION_VAR="${AWS_REGION_VAR:-$AWS_REGION}"
NAME_PREFIX="${NAME_PREFIX:-fastapi}"
ENVIRONMENT="${ENVIRONMENT:-dev}"

GITHUB_OWNER="${GITHUB_OWNER:-}"
GITHUB_REPO="${GITHUB_REPO:-}"
ALLOWED_BRANCHES="${ALLOWED_BRANCHES:-main}"

TRUSTED_ROLE_ARNS="${TRUSTED_ROLE_ARNS:-}"

usage() {
  cat <<EOF
Usage:
  TF_BACKEND_BUCKET=<s3-bucket> TF_BACKEND_DYNAMO_TABLE=<dynamodb> \\
  GITHUB_OWNER=<owner> GITHUB_REPO=<repo> [ALLOWED_BRANCHES="main,release/*"] \\
  ./run.sh <check|init|plan|apply|outputs|destroy>

Required env:
  TF_BACKEND_BUCKET, TF_BACKEND_DYNAMO_TABLE
  GITHUB_OWNER, GITHUB_REPO

Optional env:
  ALLOWED_BRANCHES="main"
  NAME_PREFIX=fastapi
  ENVIRONMENT=dev
  TRUSTED_ROLE_ARNS="arn:aws:iam::<acct>:role/engineering-admin,arn:aws:iam::<acct>:role/another"

Examples:
  export AWS_REGION=eu-west-3
  export TF_BACKEND_BUCKET="tfstate-<handle>-euw3"
  export TF_BACKEND_DYNAMO_TABLE="terraform-locks"
  export GITHUB_OWNER="TekPi2r"
  export GITHUB_REPO="fastapi-cloud-start-template"
  ./run.sh init
  ./run.sh plan
  ./run.sh apply
  ./run.sh outputs
EOF
}

require() { command -v "$1" >/dev/null 2>&1 || { echo "Missing: $1"; exit 1; }; }

preflight() {
  require aws
  require terraform
  [[ -n "$TF_BACKEND_BUCKET" ]] || { echo "TF_BACKEND_BUCKET required"; exit 1; }
  [[ -n "$TF_BACKEND_DYNAMO_TABLE" ]] || { echo "TF_BACKEND_DYNAMO_TABLE required"; exit 1; }
  [[ -n "$GITHUB_OWNER" ]] || { echo "GITHUB_OWNER required"; exit 1; }
  [[ -n "$GITHUB_REPO" ]] || { echo "GITHUB_REPO required"; exit 1; }
  aws sts get-caller-identity >/dev/null
  echo "AWS_REGION=$AWS_REGION TF_BACKEND_BUCKET=$TF_BACKEND_BUCKET TF_BACKEND_DYNAMO_TABLE=$TF_BACKEND_DYNAMO_TABLE GITHUB_OWNER=$GITHUB_OWNER GITHUB_REPO=$GITHUB_REPO"
}

init_cmd() {
  terraform init \
    -backend-config="bucket=${TF_BACKEND_BUCKET}" \
    -backend-config="key=bootstrap-foundation/terraform.tfstate" \
    -backend-config="region=${AWS_REGION}" \
    -backend-config="dynamodb_table=${TF_BACKEND_DYNAMO_TABLE}" \
    -backend-config="encrypt=true"
}

to_hcl_list() {
  local raw="${1:-}"
  if [ -z "$raw" ]; then
    echo "[]"
    return
  fi
  # split par virgule
  IFS=',' read -ra parts <<< "$raw"
  local out=()
  for p in "${parts[@]}"; do
    p="$(echo "$p" | xargs)"             # trim
    [ -z "$p" ] && continue
    p="${p//\"/\\\"}"                    # escape "
    out+=("\"$p\"")
  done
  local joined
  joined=$(IFS=, ; echo "${out[*]}")
  echo "[$joined]"
}

plan_cmd() {
  terraform validate
  local BRANCHES_HCL
  BRANCHES_HCL="$(to_hcl_list "${ALLOWED_BRANCHES:-}")"
  local TRUSTED_HCL
  TRUSTED_HCL="$(to_hcl_list "${TRUSTED_ROLE_ARNS:-}")"

  terraform plan \
    -var "aws_region=${AWS_REGION_VAR}" \
    -var "name_prefix=${NAME_PREFIX}" \
    -var "environment=${ENVIRONMENT}" \
    -var "github_owner=${GITHUB_OWNER}" \
    -var "github_repo=${GITHUB_REPO}" \
    -var "allowed_branches=${BRANCHES_HCL}" \
    -var "trusted_role_arns=${TRUSTED_HCL}"
}

apply_cmd() {
  local BRANCHES_HCL
  BRANCHES_HCL="$(to_hcl_list "${ALLOWED_BRANCHES:-}")"
  local TRUSTED_HCL
  TRUSTED_HCL="$(to_hcl_list "${TRUSTED_ROLE_ARNS:-}")"

  terraform apply -auto-approve \
    -var "aws_region=${AWS_REGION_VAR}" \
    -var "name_prefix=${NAME_PREFIX}" \
    -var "environment=${ENVIRONMENT}" \
    -var "github_owner=${GITHUB_OWNER}" \
    -var "github_repo=${GITHUB_REPO}" \
    -var "allowed_branches=${BRANCHES_HCL}" \
    -var "trusted_role_arns=${TRUSTED_HCL}"
}

destroy_cmd() {
  local BRANCHES_HCL
  BRANCHES_HCL="$(to_hcl_list "${ALLOWED_BRANCHES:-}")"
  local TRUSTED_HCL
  TRUSTED_HCL="$(to_hcl_list "${TRUSTED_ROLE_ARNS:-}")"

  terraform destroy -auto-approve \
    -var "aws_region=${AWS_REGION_VAR}" \
    -var "name_prefix=${NAME_PREFIX}" \
    -var "environment=${ENVIRONMENT}" \
    -var "github_owner=${GITHUB_OWNER}" \
    -var "github_repo=${GITHUB_REPO}" \
    -var "allowed_branches=${BRANCHES_HCL}" \
    -var "trusted_role_arns=${TRUSTED_HCL}"
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
