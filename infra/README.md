# 🏗️ Infrastructure (Terraform) — Centralized README

This folder contains a production‑ready **DevSecOps** layout split into three independent Terraform stacks:

- **`bootstrap-create/`** — Creates remote Terraform state: **S3** bucket + **DynamoDB** lock table (run once per account/region).
- **`bootstrap-foundation/`** — Configures **GitHub OIDC** + a **least‑privilege CI role** (`fastapi-ci`) trusted for selected branches. No local principals.
- **`dev-ecs/`** — Runs the app on **AWS ECS Fargate** behind an **ALB**, with **ECR** and **CloudWatch Logs**. Minimal IAM, tag-guarded.

Each stack is isolated with its own `providers.tf`, `variables.tf`, `outputs.tf`, and `run.sh`. You can apply/destroy them independently.

---

## ✅ Prerequisites

- **Terraform** ≥ 1.5
- **AWS CLI** ≥ 2.7
- An AWS profile with permissions to create S3/Dynamo/ IAM/ ECS/ ECR/ ALB (for bootstrap use an admin, then switch to CI role).
- Bash/zsh to run the helper `run.sh` scripts.

Recommended bash profile snippet:

```bash
export AWS_PROFILE="bootstrap"     # admin/engineer account for bootstraps only
export AWS_REGION="eu-west-3"
```

---

## 📁 Layout

```
infra/
├─ bootstrap-create/        # S3 state bucket + DynamoDB lock table
├─ bootstrap-foundation/    # GitHub OIDC provider + CI role (least privilege)
└─ dev-ecs/                 # ECR + ECS Fargate + ALB + Logs (dev environment)
```

---

## 1) `bootstrap-create/` — Remote State

Creates a secure **S3** bucket (SSE, versioning, block public access, deny non‑TLS) and **DynamoDB** table for state locking.

### Env vars
```bash
export AWS_PROFILE="bootstrap"
export AWS_REGION="eu-west-3"
export BUCKET_NAME="tfstate-<unique>-euw3"   # must be globally unique
```

### Commands
```bash
cd infra/bootstrap-create
./run.sh check
./run.sh init
./run.sh plan
./run.sh apply
./run.sh outputs    # prints tf_state_bucket + tf_lock_table
```

### Outputs
- `tf_state_bucket` — S3 bucket name (store TF state)
- `tf_lock_table` — DynamoDB table name (state locking)

> Run this **once** per account/region. Other stacks will point their backends to this bucket/table.

---

## 2) `bootstrap-foundation/` — GitHub OIDC + CI Role

Sets up secure CI access via **GitHub OIDC** (no long‑lived keys). Creates role `fastapi-ci` with **least privilege** and **tag guard**. Trust is **branch‑scoped** and optionally **team‑scoped** via `trusted_role_arns` (kept empty by default for stricter posture).

### Backend env (use outputs from step 1)
```bash
export TF_BACKEND_BUCKET="tfstate-<unique>-euw3"
export TF_BACKEND_DYNAMO_TABLE="terraform-locks"
```

### Inputs
```bash
export GITHUB_OWNER="TekPi2r"
export GITHUB_REPO="fastapi-cloud-start-template"
export ALLOWED_BRANCHES="main"              # comma-separated, e.g., "main,release/*"
export TRUSTED_ROLE_ARNS=""                 # optional, comma-separated
```

### Commands
```bash
cd infra/bootstrap-foundation
./run.sh init
./run.sh plan
./run.sh apply
./run.sh outputs    # ci_role_arn + github_oidc_provider_arn
```

### Outputs
- `ci_role_arn` — IAM role to assume from GitHub Actions
- `github_oidc_provider_arn` — OIDC provider ARN

### What the CI role can do (scoped)
- **ECR**: create repo `fastapi-dev`, push/pull, lifecycle policy (scoped to that repo).
- **Logs**: manage `/fastapi/dev` log group.
- **IAM (runtime)**: create/attach only **approved** policies/roles for **ECS tasks** (scoped by name).
- **EC2/ECS/ALB**: only actions needed to run ECS on Fargate, protected by **tag guards** (`Environment=dev`, `ManagedBy=Terraform`).

> No local developer identity is allowed to assume the CI role by default (production posture).

---

## 3) `dev-ecs/` — ECS Fargate + ALB + ECR + Logs

Provisions a simple **public ALB → ECS Fargate** service (`fastapi-dev-svc`) that pulls image from **ECR** (`fastapi-dev`), and streams logs to **CloudWatch Logs**. Uses the **default VPC & 2 public subnets** by default.

### Inputs (common)
```bash
export AWS_PROFILE="bootstrap"              # for manual apply; CI will assume fastapi-ci
export AWS_REGION="eu-west-3"
export NAME_PREFIX="fastapi"
export IMAGE_TAG="latest"                   # optional: image tag to run
```

### Commands
```bash
cd infra/dev-ecs
./run.sh init
./run.sh plan
./run.sh apply
./run.sh outputs
```

### Outputs
- `ecr_repo_url` — ECR repo to push images to
- `cluster_name` — ECS cluster name
- `service_name` — ECS service name
- `alb_dns_name` — Public URL (HTTP, port 80)
- `log_group_name` — CloudWatch Logs group
- `task_role_arn` — IAM role for the running task (runtime permissions)

### Notes
- **TLS**: this stack currently exposes **HTTP** on port 80. Plan to add **ACM cert + HTTPS listener (443)** next.
- **VPC**: it uses the **default VPC** for simplicity. For production, switch to a dedicated VPC with public ALB + private ECS subnets.
- **Image**: The service expects images like `${ecr_repo_url}:${IMAGE_TAG}`.

---

## 🔄 CI/CD Integration (GitHub Actions via OIDC)

1) From `bootstrap-foundation/outputs`, grab `ci_role_arn`.
2) In GitHub repo **Actions secrets and variables → Secrets** add:
   - `AWS_ROLE_TO_ASSUME` = the `ci_role_arn` value
   - `AWS_REGION` = `eu-west-3`

3) Example workflow (high level, adjust to your paths):
```yaml
name: Deploy Dev (ECS)

on:
  push:
    branches: [ "main" ]

permissions:
  id-token: write
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS (OIDC)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_TO_ASSUME }}
          aws-region: ${{ secrets.AWS_REGION }}

      - name: Log in to ECR
        id: ecr
        uses: aws-actions/amazon-ecr-login@v2

      - name: Build & push image
        run: |
          IMAGE="${{ steps.ecr.outputs.registry }}/fastapi-dev:${{ github.sha }}"
          docker build -t "$IMAGE" .
          docker push "$IMAGE"
          echo "IMAGE=$IMAGE" >> $GITHUB_ENV

      - name: Terraform apply (dev-ecs)
        working-directory: infra/dev-ecs
        env:
          TF_VAR_image_tag: ${{ github.sha }}
        run: |
          terraform init \
            -backend-config="bucket=${{ env.TF_BACKEND_BUCKET }}" \
            -backend-config="key=dev-ecs/terraform.tfstate" \
            -backend-config="region=${{ secrets.AWS_REGION }}" \
            -backend-config="dynamodb_table=terraform-locks" \
            -backend-config="encrypt=true"
          terraform apply -auto-approve
```

> This runs entirely with **OIDC** — no static AWS keys. It builds the Docker image, pushes to **ECR**, then applies the **Terraform** stack to roll the service.

---

## 🔒 Security & DevSecOps Notes

- **Least privilege** everywhere; CI role permissions are **scoped by resource name** and **tag guards**.
- **No local principals** in trust policy by default (add only if you must — via `TRUSTED_ROLE_ARNS`).
- **State security**: S3 bucket is private, versioned, encrypted; DynamoDB locking enabled; deny non‑TLS access.
- **Image hygiene**: ECR lifecycle keeps last 10; enable scanning (already enabled).
- **Secrets**: Prefer **SSM Parameter Store** / **Secrets Manager** mounted into task definitions over plain env vars.
- **TLS/ACM**: add HTTPS listener and ACM certificate for the ALB (next step).
- **WAF**: consider attaching AWS WAF to the ALB for basic L7 protections.
- **Scanning**: keep **Trivy** (images) and add **Semgrep** (SAST) / **OWASP ZAP** (DAST) in CI.

---

## 🧰 Troubleshooting

- **S3 bucket does not exist** → Run `bootstrap-create` first and point other stacks’ backends to its outputs.
- **Duplicate providers/outputs** → Ensure each folder has its own `providers.tf` and no duplicated blocks in the same module.
- **ECR repo not empty on destroy** → Delete images or set `force_delete = true` (trade‑off).
- **ECS “taskRoleArn required”** → Ensure the **task runtime role** is created and referenced by the task definition.
- **ALB stuck creating** → Subnets must be valid and have internet route; security group allows 80 (and 443 when enabled).

---

## 🧹 Clean up

Destroy stacks **in reverse order**:

```bash
cd infra/dev-ecs && ./run.sh destroy
cd ../bootstrap-foundation && ./run.sh destroy   # leave if CI still needs it
cd ../bootstrap-create && ./run.sh destroy       # only if no other TF states use it
```

---

## 🗺️ Roadmap

- ✅ Remote state (S3+Dynamo), GitHub OIDC, CI role (least privilege)
- ✅ ECS Fargate + ALB (HTTP), ECR, Logs
- 🔜 **TLS/ACM** + HTTPS (443) listener and redirect 80→443
- 🔜 Private VPC with public ALB + private ECS subnets + NAT + SG hardening
- 🔜 Secrets via SSM/Secrets Manager in task definition
- 🔜 Autoscaling policies (CPU/memory/ALB request count)
- 🔜 Blue/Green or canary deploys (CodeDeploy for ECS or rolling updates)
- 🔜 WAF + rate limiting
- 🔜 SAST/DAST in CI (Semgrep/ZAP)

---

**Questions / updates?** Ping in the repo and i will iterate 🚀
