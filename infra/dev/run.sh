#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────────────────────────────────────
# 🚀 Dev Runner (ECR + EC2 + CloudWatch)
#    - Backend TF: S3/DynamoDB (from bootstrap)
#    - Commands: check / init / plan / apply / outputs / destroy
#                status / logs / hit / redeploy / local-clean
#    - Extras  : ecr-login / ecr-push (linux/amd64)
# ──────────────────────────────────────────────────────────────────────────────

# Always run from this script's directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Resolve repo root (works with or without git)
REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || (cd "$SCRIPT_DIR/../.." && pwd))}"

# ── Log helpers (no ANSI colors, just emojis) ─────────────────────────────────
info()  { echo "ℹ️  $*"; }
ok()    { echo "✅ $*"; }
warn()  { echo "⚠️  $*"; }
err()   { echo "❌ $*"; }
title() { echo; echo "## $*"; }

trap 'echo "❌ An error occurred. Check the last command output above."' ERR

# ── Defaults (override via env) ───────────────────────────────────────────────
AWS_PROFILE="${AWS_PROFILE:-bootstrap}"
AWS_REGION="${AWS_REGION:-eu-west-3}"

TF_BACKEND_BUCKET="${TF_BACKEND_BUCKET:-}"              # <- bootstrap output: s3_bucket_name
TF_BACKEND_DYNAMO_TABLE="${TF_BACKEND_DYNAMO_TABLE:-}"  # <- bootstrap output: dynamodb_table_name

AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-}"                    # e.g. $(aws sts get-caller-identity --query Account --output text)
ECR_REPO="${ECR_REPO:-fastapi-dev}"
IMAGE_TAG="${IMAGE_TAG:-dev}"
NAME_PREFIX="${NAME_PREFIX:-fastapi-dev}"
INSTANCE_TYPE="${INSTANCE_TYPE:-t3.micro}"
VPC_ID="${VPC_ID:-}"                                    # empty -> default VPC

export AWS_PROFILE AWS_REGION

# ── Helpers ───────────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
🧭 Usage:
  (env) $0 <check|init|plan|apply|outputs|destroy|status|logs|hit|redeploy|ecr-login|ecr-push|local-clean|help>

🔐 Required env:
  - TF_BACKEND_BUCKET, TF_BACKEND_DYNAMO_TABLE (from bootstrap)
  - AWS_PROFILE=${AWS_PROFILE}
  - AWS_REGION=${AWS_REGION}
  - AWS_ACCOUNT_ID (auto-detected if empty)

🔧 Optional env:
  - ECR_REPO=${ECR_REPO}
  - IMAGE_TAG=${IMAGE_TAG}
  - NAME_PREFIX=${NAME_PREFIX}
  - INSTANCE_TYPE=${INSTANCE_TYPE}
  - VPC_ID=${VPC_ID}

⚡ Quickstart:
  export AWS_PROFILE="bootstrap"
  export AWS_REGION="eu-west-3"
  export TF_BACKEND_BUCKET="tfstate-<handle>-euw3"
  export TF_BACKEND_DYNAMO_TABLE="terraform-locks"
  export AWS_ACCOUNT_ID=\$(aws sts get-caller-identity --query Account --output text --profile "\$AWS_PROFILE")

  ./run.sh check
  ./run.sh init && ./run.sh plan && ./run.sh apply
  ./run.sh status && ./run.sh hit && ./run.sh logs
EOF
}

has_cmd() { command -v "$1" >/dev/null 2>&1; }

# ── Commands ──────────────────────────────────────────────────────────────────
preflight() {
  title "🔎 Pre-flight"
  has_cmd aws || { err "AWS CLI missing"; exit 1; }
  has_cmd terraform || { err "Terraform missing"; exit 1; }
  has_cmd jq || warn "jq not found (optional, but useful)"

  [[ -n "$TF_BACKEND_BUCKET" ]]       || { err "TF_BACKEND_BUCKET required"; exit 1; }
  [[ -n "$TF_BACKEND_DYNAMO_TABLE" ]] || { err "TF_BACKEND_DYNAMO_TABLE required"; exit 1; }

  if [[ -z "$AWS_ACCOUNT_ID" ]]; then
    info "Resolving AWS_ACCOUNT_ID via STS…"
    AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text --profile "$AWS_PROFILE")" || {
      err "Cannot get AWS identity (profile=$AWS_PROFILE)"; exit 1;
    }
  fi

  info "Profile: ${AWS_PROFILE}  Region: ${AWS_REGION}  Account: ${AWS_ACCOUNT_ID}"
  aws sts get-caller-identity --profile "$AWS_PROFILE" >/dev/null
  ok "AWS auth OK"

  # Heads-up if s3 backend block isn't declared (to avoid TF warning)
  if ! grep -q 'backend *"s3"' providers.tf 2>/dev/null; then
    warn 'S3 backend not declared in providers.tf -> Terraform will warn. Add: terraform { backend "s3" {} }'
  fi
}

init_backend() {
  title "🧱 terraform init (S3 backend)"
  terraform init \
    -backend-config="bucket=${TF_BACKEND_BUCKET}" \
    -backend-config="key=dev/terraform.tfstate" \
    -backend-config="region=${AWS_REGION}" \
    -backend-config="dynamodb_table=${TF_BACKEND_DYNAMO_TABLE}"
  ok "Init done"
}

plan_cmd() {
  title "📝 terraform plan"
  terraform fmt -recursive >/dev/null || true
  terraform validate
  terraform plan \
    -var "aws_region=${AWS_REGION}" \
    -var "aws_account_id=${AWS_ACCOUNT_ID}" \
    -var "ecr_repo_name=${ECR_REPO}" \
    -var "image_tag=${IMAGE_TAG}" \
    -var "name_prefix=${NAME_PREFIX}" \
    -var "instance_type=${INSTANCE_TYPE}" \
    -var "vpc_id=${VPC_ID}"
}

apply_cmd() {
  title "🚢 terraform apply"
  terraform apply -auto-approve \
    -var "aws_region=${AWS_REGION}" \
    -var "aws_account_id=${AWS_ACCOUNT_ID}" \
    -var "ecr_repo_name=${ECR_REPO}" \
    -var "image_tag=${IMAGE_TAG}" \
    -var "name_prefix=${NAME_PREFIX}" \
    -var "instance_type=${INSTANCE_TYPE}" \
    -var "vpc_id=${VPC_ID}"
  ok "Apply done"
}

destroy_cmd() {
  title "💥 terraform destroy"
  terraform destroy -auto-approve \
    -var "aws_region=${AWS_REGION}" \
    -var "aws_account_id=${AWS_ACCOUNT_ID}" \
    -var "ecr_repo_name=${ECR_REPO}" \
    -var "image_tag=${IMAGE_TAG}" \
    -var "name_prefix=${NAME_PREFIX}" \
    -var "instance_type=${INSTANCE_TYPE}" \
    -var "vpc_id=${VPC_ID}"
  ok "Destroy done"
}

status_cmd() {
  title "📊 Status (outputs + existence)"
  terraform output || true
  if aws ecr describe-repositories --repository-names "$ECR_REPO" --region "$AWS_REGION" --profile "$AWS_PROFILE" >/dev/null 2>&1; then
    ok "ECR repo exists: ${ECR_REPO}"
  else
    warn "ECR repo not found: ${ECR_REPO}"
  fi
  if has_cmd curl; then
    local IP
    IP="$(terraform output -raw instance_public_ip 2>/dev/null || true)"
    if [[ -n "${IP:-}" ]]; then
      info "HTTP check http://$IP/ …"
      if curl -s --max-time 2 "http://$IP/" >/dev/null; then ok "HTTP OK"; else warn "HTTP not reachable (yet)"; fi
    fi
  fi
}

logs_cmd() {
  title "📜 CloudWatch Logs (tail)"
  local LG
  LG="$(terraform output -raw log_group_name 2>/dev/null || echo "/fastapi/dev")"
  aws logs tail "$LG" --since 10m --follow --region "$AWS_REGION" --profile "$AWS_PROFILE"
}

hit_cmd() {
  title "🌐 HTTP check"
  has_cmd curl || { err "curl required for 'hit'"; exit 1; }
  local IP
  IP="$(terraform output -raw instance_public_ip)"
  info "Request: http://$IP/health"
  curl -i "http://$IP/health"
}

redeploy_cmd() {
  title "🔁 Redeploy (re-run user_data by recreating EC2)"
  terraform taint aws_instance.api || true
  init_backend
  apply_cmd
  ok "Instance recreated. Use 'hit' or 'logs' to verify."
}

ecr_login_cmd() {
  title "🔑 ECR login"
  local REPO_URL
  REPO_URL="$(terraform output -raw ecr_repo_url)"
  aws ecr get-login-password --region "$AWS_REGION" --profile "$AWS_PROFILE" \
    | docker login --username AWS --password-stdin "${REPO_URL%/*}"
  ok "ECR login OK"
}

ecr_push_cmd() {
  title "📦 Build & Push image (linux/amd64)"
  has_cmd docker || { err "Docker required for ecr-push"; exit 1; }
  local REPO_URL
  REPO_URL="$(terraform output -raw ecr_repo_url)"
  [[ -f "$REPO_ROOT/Dockerfile" ]] || { err "Dockerfile not found: $REPO_ROOT/Dockerfile"; exit 1; }

  docker buildx create --use >/dev/null 2>&1 || true
  info "Context: $REPO_ROOT"
  info "Image: ${REPO_URL}:${IMAGE_TAG}"
  docker buildx build \
    --platform linux/amd64 \
    -f "$REPO_ROOT/Dockerfile" \
    -t "${REPO_URL}:${IMAGE_TAG}" \
    --push \
    "$REPO_ROOT"
  ok "Image pushed"
}

local_clean_cmd() {
  title "🧹 Local clean (Terraform files)"
  echo "⚠️  WARNING: This will DELETE all local Terraform state & lock files in this folder."
  read -p "Type 'yes' to confirm: " confirm
  if [ "$confirm" != "yes" ]; then
    echo "❌ Aborted."
    exit 1
  fi
  rm -rf .terraform .terraform.lock.hcl terraform.tfstate* tfplan || true
  ok "Local Terraform files removed"
}

# ── Router ────────────────────────────────────────────────────────────────────
CMD="${1:-help}"
case "$CMD" in
  help|-h|--help) usage ;;
  check)          preflight ;;
  init)           preflight; init_backend ;;
  plan)           preflight; init_backend; plan_cmd ;;
  apply)          preflight; init_backend; apply_cmd ;;
  outputs)        terraform output || true ;;
  destroy)        preflight; init_backend; destroy_cmd ;;
  status)         preflight; status_cmd ;;
  logs)           preflight; logs_cmd ;;
  hit)            preflight; hit_cmd ;;
  redeploy)       preflight; redeploy_cmd ;;
  ecr-login)      preflight; ecr_login_cmd ;;
  ecr-push)       preflight; ecr_push_cmd ;;
  local-clean)    local_clean_cmd ;;
  *)              usage; exit 1 ;;
esac
