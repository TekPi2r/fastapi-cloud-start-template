# 🏗️ Infrastructure (Terraform) — Centralized README

This folder contains all Terraform code and helper scripts to provision and operate the **FastAPI on ECS Fargate** stack in AWS — built with **security‑by‑design** 🔐 and CI/CD‑first 🚀.

> **TL;DR**
> - Local (one‑time): `bootstrap-create/` then `bootstrap-foundation/` 🧱  
> - App infra: `env/dev-ecs/` (local for first run, CI for subsequent changes) 🧩  
> - Pipelines: `.github/workflows/{app-ci.yml, app-deploy-dev.yml}` 🐳⚙️

---

## ✅ Prerequisites

- **Terraform** ≥ 1.5
- **AWS CLI** ≥ 2.7
- An AWS profile with permissions to create **S3/DynamoDB/IAM/ECS/ECR/ALB** (for bootstrap use an admin; afterwards use CI roles).
- Bash/zsh to run the helper `run.sh` scripts.

Recommended profile snippet for local work:

```bash
export AWS_PROFILE="bootstrap"     # admin/engineer account for bootstraps only
export AWS_REGION="eu-west-3"
```

---

## 🗂️ Layout

```
infra/
├─ bootstrap-create/        # S3 state bucket + DynamoDB locks (one-time, local)
├─ bootstrap-foundation/    # GitHub OIDC provider + IAM build/deploy roles (local)
└─ env/
   └─ dev-ecs/              # ECS runtime (network, ALB, ECS/Fargate, logs, autoscaling)
```

- **bootstrap-create/**: Creates the Terraform backend (S3 + DynamoDB). No app resources.
- **bootstrap-foundation/**: Creates the GitHub OIDC provider and two least‑privilege IAM roles:
  - `fastapi-dev-build` → used by CI to **build & push** Docker images to ECR.
  - `fastapi-dev-deploy` → used by CI to **plan/apply** Terraform in `infra/env/dev-ecs`.
- **env/dev-ecs/**: The actual app infra (ECR repo, ECS cluster/service/task definition, ALB, log group, SGs).

---

## 🧾 Naming & Conventions

- **Project prefix**: `fastapi`
- **Environment**: `dev`
- **Derived names**:
  - `local.name` → `fastapi-dev`
  - **ECR repo** → `fastapi-dev-ecr` 📦
  - **Log group** → `/fastapi/dev` 🪵
  - **Cluster** → `fastapi-dev-cluster`
  - **Service** → `fastapi-dev-svc`
  - **Task family** → `fastapi-dev-api`

> No hard‑coded repo/log names in CI. They’re computed from `NAME_PREFIX` + `ENVIRONMENT` ✅

---

## 🔐 Security (OIDC + least privilege)

**bootstrap-foundation** sets up:
- An AWS **IAM OIDC provider** for `https://token.actions.githubusercontent.com`.
- Two roles with **web identity** trust:
  - **Allowed subjects**: branch refs (e.g., `main`) and environment runs (e.g., `environment:dev`).
  - **Audience**: `sts.amazonaws.com`.
- Policies are **scoped** to the minimum required — production‑ready defaults ✅.

**Build role** (`fastapi-dev-build`): minimal **ECR push** on the single repo.

**Deploy role** (`fastapi-dev-deploy`):
- **ECS**: `RegisterTaskDefinition`, `UpdateService`, `Describe*`, `List*`, `TagResource`.
- **IAM**: `PassRole` **only** for the two ECS task roles (`*-ecs-task-exec`, `*-ecs-task`) + read (`GetRole`, `ListRolePolicies`, `ListAttachedRolePolicies`, `GetRolePolicy`) on those roles.
- **ECR (read)**: `DescribeRepositories`, `DescribeImages`, `BatchGetImage`, `GetDownloadUrlForLayer`, `ListTagsForResource`, `GetLifecyclePolicy`.
- **Terraform backend**: S3 bucket/object ops on the backend prefix + DynamoDB lock RW.
- **Describe‑only reads** used by Terraform state refresh:
  - **EC2**: `DescribeVpcs`, `DescribeSubnets`, `DescribeSecurityGroups`, `DescribeVpcAttribute`, `DescribeAccountAttributes`, `DescribeAvailabilityZones`
  - **ELBv2**: `DescribeLoadBalancers`, `DescribeListeners`, `DescribeTargetGroups`, `DescribeRules`, `DescribeTargetHealth`, `DescribeLoadBalancerAttributes`, `DescribeTargetGroupAttributes`, `DescribeListenerAttributes`, `DescribeTags`
  - **CloudWatch Logs**: `DescribeLogGroups`, `ListTagsForResource`

> Keep the **AWS account ID** out of repo files; ARNs live in GitHub Environment config, not in code 👍

---

## 🧪 Pipelines (GitHub Actions)

Located in `.github/workflows/`:

### 1) `app-ci.yml` — Build & push image 🐳
- **Triggers**: PRs and push to `main`.
- **Role**: `AWS_ROLE_BUILD_ARN` (environment `dev`).
- **Tags**: `latest-dev` and short commit SHA.
- **Output**: Image pushed to `${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/fastapi-dev-ecr`.

### 2) `app-deploy-dev.yml` — Plan & apply Terraform ⚙️
- **Trigger**: manual **workflow_dispatch** (recommended) or on demand.
- **Role**: `AWS_ROLE_DEPLOY_ARN` (environment `dev`).
- **Plan**: Runs `infra/env/dev-ecs/run.sh plan` — exit code **2** is treated as “changes found” (✅).
- **Apply**: Runs `infra/env/dev-ecs/run.sh apply`, updates the task definition to the selected `IMAGE_TAG`.
- **Output**: ALB URL (e.g., `http://fastapi-dev-alb-XXXX.eu-west-3.elb.amazonaws.com/`).

> The `dev` **Environment** provides gated approvals 🙋‍♂️ and safely scoped variables.

---

## ⚙️ Environment Configuration (GitHub → Settings → Environments → `dev`)

Set as **environment variables** (non‑secret):
- `AWS_REGION` → `eu-west-3`
- `ENVIRONMENT` → `dev`
- `NAME_PREFIX` → `fastapi`
- `TF_BACKEND_BUCKET` → your S3 state bucket (e.g., `tfstate-pi2r-devsecops-project-euw3`)
- `TF_BACKEND_DYNAMO_TABLE` → `terraform-locks`
- `AWS_ROLE_BUILD_ARN` → output of `bootstrap-foundation` (e.g., `arn:aws:iam::...:role/fastapi-dev-build`)
- `AWS_ROLE_DEPLOY_ARN` → output of `bootstrap-foundation` (e.g., `arn:aws:iam::...:role/fastapi-dev-deploy`)

Optional protection:
- **Required reviewers** for `dev` deployments 🙋
- **Wait timer** before apply ⏳

---

## 🚀 End‑to‑End Flow

1. **Local once** — Backend:
   ```bash
   # infra/bootstrap-create
   export AWS_PROFILE=bootstrap
   export AWS_REGION=eu-west-3
   export BUCKET_NAME="tfstate-<your-handle>-euw3"
   ./run.sh apply
   ```

2. **Local once** — Foundation (OIDC + roles):
   ```bash
   # infra/bootstrap-foundation
   export AWS_PROFILE=bootstrap
   export AWS_REGION=eu-west-3
   export TF_BACKEND_BUCKET="<bucket-from-step-1>"
   export TF_BACKEND_DYNAMO_TABLE="terraform-locks"
   export GITHUB_OWNER="TekPi2r"
   export GITHUB_REPO="fastapi-cloud-start-template"
   ./run.sh apply
   ```
   Copy the **role ARNs** to GitHub Environment `dev`.

3. **App infra** — First run local (optional), then CI:
   ```bash
   # infra/env/dev-ecs (local optional first run)
   export AWS_PROFILE=bootstrap
   export AWS_REGION=eu-west-3
   export TF_BACKEND_BUCKET="<bucket>"
   export TF_BACKEND_DYNAMO_TABLE="terraform-locks"
   ./run.sh apply
   ```

4. **CI Build** — On push/PR, `app-ci.yml` builds & pushes image 🐳.

5. **CI Deploy** — Manually trigger `app-deploy-dev.yml`, choose the `IMAGE_TAG` you want to deploy 🚀.

---

## 🔧 `env/dev-ecs/run.sh` cheatsheet

```bash
./run.sh check                # preflight (aws/terraform present + backend vars)
./run.sh plan                 # terraform plan (exit-code 2 == "changes")
./run.sh apply                # terraform apply
./run.sh destroy              # ⚠️ destroy app infra (not backend)
./run.sh outputs              # show outputs (ECR URL, cluster, service, etc.)
./run.sh ecr-login            # docker login to ECR (helper)
./run.sh ecr-push             # buildx push to computed repo:tag
./run.sh url                  # print ALB URL
```

Key envs (auto‑computed when possible):
- `IMAGE_TAG` (defaults `dev`; CI uses commit SHA or `latest-dev`).
- `LOG_GROUP_NAME` (`/fastapi/dev`), `NAME_PREFIX` (`fastapi`), `ENVIRONMENT` (`dev`).

**Health/Logs**
- Target group health check path: `/` (port **8000**).  
- ECS service events: **ECS → Cluster → Services → Events**.  
- App logs: **CloudWatch Logs** group **`/fastapi/dev`** 📜.

---

## 🧰 Troubleshooting

- **403 during plan/apply in CI** → The deploy role is missing a read permission.
  - Re‑run `bootstrap-foundation` after updating IAM to include the new read‑only actions (e.g., `elasticloadbalancing:Describe*`, `logs:ListTagsForResource`, `ecr:GetLifecyclePolicy`, `elasticloadbalancing:DescribeTags`, `elasticloadbalancing:DescribeListenerAttributes`).  
- **503 on ALB** → Wrong `IMAGE_TAG` or task not healthy.
  - Re‑deploy with a **valid** tag from ECR, check ECS service events + CloudWatch logs.
- **Backend prompts for input locally** → Export the required envs: `TF_BACKEND_BUCKET`, `TF_BACKEND_DYNAMO_TABLE`, `AWS_REGION`.

---

## 🧹 Teardown (order matters)

1) **App infra** (safe to repeat):
```bash
cd infra/env/dev-ecs
./run.sh destroy
```

2) **Foundation** (OIDC + roles):
```bash
cd ../bootstrap-foundation
./run.sh destroy
```

3) **Backend** (S3 + DynamoDB):
```bash
cd ../bootstrap-create
./run.sh destroy
```

> Don’t destroy the backend until all state consumers are gone 🛑

---

## 🧭 Roadmap / Ideas

- Blue/Green or Canary with multiple target groups 🎛️
- HTTPS with ACM + 443 listener 🔒
- WAFv2 on ALB 🛡️
- Staging/prod environments via workspaces or folders 🌐
- GitHub OIDC subject rules per env/branch for tighter scoping 🎯

---

## ✅ Quick checklist

- [x] Backend created (S3/DynamoDB)
- [x] OIDC provider + roles applied
- [x] GitHub `dev` environment variables set
- [x] First image built & pushed by `app-ci.yml`
- [x] Service deployed by `app-deploy-dev.yml`
- [x] ALB URL returns `200 OK`

Happy shipping! 🚀

---

## 🔄 State migration cheat sheet

Coming from the previous `infra/dev-ecs` layout, run the `state mv` commands **before** your next `plan` so Terraform keeps the existing resources:

### Foundation (run in `infra/bootstrap-foundation`)

```bash
terraform state mv aws_ecr_repository.fastapi_dev \
  module.ecr_dev.aws_ecr_repository.this
terraform state mv aws_ecr_lifecycle_policy.fastapi_dev \
  module.ecr_dev.aws_ecr_lifecycle_policy.this
terraform state mv aws_iam_role.fastapi_build \
  module.iam_build.aws_iam_role.this
terraform state mv aws_iam_policy.fastapi_build_min \
  module.iam_build.aws_iam_policy.this
terraform state mv aws_iam_role_policy_attachment.fastapi_build_attach \
  module.iam_build.aws_iam_role_policy_attachment.this
terraform state mv aws_iam_role.fastapi_deploy \
  module.iam_deploy.aws_iam_role.this
terraform state mv aws_iam_policy.fastapi_deploy_min \
  module.iam_deploy.aws_iam_policy.this
terraform state mv aws_iam_role_policy_attachment.fastapi_deploy_attach \
  module.iam_deploy.aws_iam_role_policy_attachment.this
terraform state mv aws_iam_openid_connect_provider.github \
  module.github_oidc.aws_iam_openid_connect_provider.github
```

### Runtime env (`infra/env/dev-ecs`)

```bash
terraform state mv aws_security_group.alb \
  module.network.aws_security_group.alb
terraform state mv aws_security_group.ecs_tasks \
  module.network.aws_security_group.ecs_tasks
terraform state mv aws_security_group.vpce \
  module.network.aws_security_group.vpce
terraform state mv aws_security_group_rule.alb_to_ecs_tasks \
  module.network.aws_security_group_rule.alb_to_ecs_tasks
terraform state mv aws_security_group_rule.ecs_tasks_from_alb \
  module.network.aws_security_group_rule.ecs_tasks_from_alb
terraform state mv aws_security_group_rule.ecs_tasks_to_vpce \
  module.network.aws_security_group_rule.ecs_tasks_to_vpce
terraform state mv aws_security_group_rule.vpce_from_ecs_tasks \
  module.network.aws_security_group_rule.vpce_from_ecs_tasks
# VPC endpoints -> update the <region> placeholder
terraform state mv 'aws_vpc_endpoint.interfaces["com.amazonaws.<region>.ecr.api"]' \
  'module.network.aws_vpc_endpoint.interfaces["com.amazonaws.<region>.ecr.api"]'
# …repeat for each service (ecr.dkr, logs, ssm, ssmmessages, ec2messages)
terraform state mv aws_lb.app \
  module.alb.aws_lb.this
terraform state mv aws_lb_target_group.app \
  module.alb.aws_lb_target_group.this
terraform state mv aws_lb_listener.http \
  module.alb.aws_lb_listener.http
# (if HTTPS listener exists)
terraform state mv aws_lb_listener.https \
  module.alb.aws_lb_listener.https
terraform state mv aws_s3_bucket.alb_logs \
  module.alb.aws_s3_bucket.logs
terraform state mv aws_s3_bucket_public_access_block.alb_logs \
  module.alb.aws_s3_bucket_public_access_block.logs
terraform state mv aws_s3_bucket_ownership_controls.alb_logs \
  module.alb.aws_s3_bucket_ownership_controls.logs
terraform state mv aws_s3_bucket_versioning.alb_logs \
  module.alb.aws_s3_bucket_versioning.logs
terraform state mv aws_s3_bucket_server_side_encryption_configuration.alb_logs \
  module.alb.aws_s3_bucket_server_side_encryption_configuration.logs
terraform state mv aws_s3_bucket_policy.alb_logs \
  module.alb.aws_s3_bucket_policy.logs
terraform state mv aws_ecs_cluster.this \
  module.ecs.aws_ecs_cluster.this
terraform state mv aws_ecs_task_definition.api \
  module.ecs.aws_ecs_task_definition.this
terraform state mv aws_ecs_service.api \
  module.ecs.aws_ecs_service.this
```

> Tip: if a resource is already missing from the old state, use `terraform import` with the new address instead of `state mv`.
