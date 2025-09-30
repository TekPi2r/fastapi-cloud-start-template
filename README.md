# 🚀 FastAPI Cloud Start Template

[![Build & Push (CI)](https://github.com/TekPi2r/fastapi-cloud-start-template/actions/workflows/app-ci.yml/badge.svg)](https://github.com/TekPi2r/fastapi-cloud-start-template/actions/workflows/app-ci.yml)
[![Deploy dev](https://github.com/TekPi2r/fastapi-cloud-start-template/actions/workflows/app-deploy-dev.yml/badge.svg)](https://github.com/TekPi2r/fastapi-cloud-start-template/actions/workflows/app-deploy-dev.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
![Python](https://img.shields.io/badge/python-3.11-blue.svg)
![FastAPI](https://img.shields.io/badge/FastAPI-latest-green.svg)
![Kubernetes](https://img.shields.io/badge/Kubernetes-local--dev-blueviolet.svg)

A modern, production‑minded **FastAPI** template with a clean path to AWS:

- **Terraform** infra for **ECS Fargate + ALB + ECR** 🏗️
- **GitHub OIDC** + least‑privilege IAM 🔐
- **Two pipelines**: build/push Docker → deploy to ECS 🚢

> Prefer the full infra details in [`infra/README.md`](infra/README.md) (freshly rewritten) for deep‑dive usage & teardown.

---

## ✨ What’s inside

- **API**
  - ⚡ FastAPI + Uvicorn
  - 🔐 OAuth2 (password flow) + JWT
- **Tests & data**
  - 🧪 `pytest` (unit & integration markers)
  - 🍃 MongoDB used in integration tests
- **Containers**
  - 🐳 Production‑ready Dockerfile (non‑root, healthcheck)
- **Security**
  - 🛡️ Image scanning ready (Trivy)
  - 🔐 GitHub Actions OIDC → AWS (no long‑lived keys)
- **CI/CD**
  - 🤖 `app-ci.yml` (build & push to ECR)
  - ⚙️ `app-deploy-dev.yml` (plan/apply Terraform to ECS)

---

## 🗂️ Repo layout

```
.
├── app/                         # FastAPI app code
├── tests/                       # pytest suite
├── Dockerfile                   # container image
├── infra/                       # Terraform (S3/Dynamo backend, OIDC, ECS/ECR/ALB)
│   ├── bootstrap-create/        # S3 state bucket + DynamoDB locks (one‑time)
│   ├── bootstrap-foundation/    # GitHub OIDC + IAM roles (build/deploy) + dev ECR
│   └── dev-ecs/                 # ECS service, ALB, logs, SGs (+ run.sh)
└── .github/workflows/
    ├── app-ci.yml               # build & push to ECR
    └── app-deploy-dev.yml       # plan/apply dev-ecs
```

---

## 🔐 Security by design

- **No static AWS keys** in CI: GitHub **OIDC** + `AssumeRoleWithWebIdentity`.
- **Least privilege**:
  - `fastapi-dev-build` → ECR push scoped to **one repo**.
  - `fastapi-dev-deploy` → ECS register/update + read‑only describes; S3/Dynamo for TF backend; strict `iam:PassRole` to ECS task roles only.
- **Environment‑scoped** variables in GitHub **Environments › dev** (region, ARNs, backend names).

---

## 🚀 Quick start

### Runbook local (ordre recommandé)

1. `infra/bootstrap-create` – backend Terraform (S3/Dynamo/KMS).
2. `infra/bootstrap-foundation` – GitHub OIDC, IAM build/deploy, création du repo ECR dev.
3. `.github/workflows/app-ci.yml` – build & push vers ECR (`Check ECR exists` vérifie la présence du repo avant le build).
4. `infra/env/dev-ecs` – VPC, ECS service, ALB, logs, SGs.
5. `.github/workflows/app-deploy-dev.yml` – plan/apply Terraform (dev-ecs) via pipeline.

### 1) One-time AWS bootstrap (local)

```bash
# infra/bootstrap-create — remote TF state
export AWS_PROFILE=bootstrap
export AWS_REGION=eu-west-3
export BUCKET_NAME="tfstate-pi2r-project-euw3"   # must be globally unique
./run.sh apply

# infra/bootstrap-foundation — OIDC provider + IAM roles
export TF_BACKEND_BUCKET="tfstate-pi2r-project-euw3"
export TF_BACKEND_DYNAMO_TABLE="terraform-locks"
export GITHUB_OWNER="TekPi2r"
export GITHUB_REPO="fastapi-cloud-start-template"
./run.sh apply
# Copy role ARNs to GitHub → Settings → Environments → dev
```

### 2) Configure GitHub Environment `dev`

Set **environment variables** (non‑secret):

- `AWS_REGION=eu-west-3`
- `ENVIRONMENT=dev`
- `NAME_PREFIX=fastapi`
- `TF_BACKEND_BUCKET=<your bucket>`
- `TF_BACKEND_DYNAMO_TABLE=terraform-locks`
- `AWS_ROLE_BUILD_ARN=arn:aws:iam::<acct>:role/fastapi-dev-build`
- `AWS_ROLE_DEPLOY_ARN=arn:aws:iam::<acct>:role/fastapi-dev-deploy`

(Optionally require reviewers / wait timer ⏳.)

### 3) Build & push image (CI)

- Push to `main` → **`app-ci`** runs (`Check ECR exists` stoppe la job si le repo n’est pas encore provisionné) et pousse :
  ```
  <account>.dkr.ecr.<region>.amazonaws.com/fastapi-dev-ecr:{short-sha}
  and :latest-dev
  ```

### 4) Deploy to ECS (CI)

- Manually trigger **`app-deploy-dev`** → choose `IMAGE_TAG` (e.g. `latest-dev`).
- The workflow plans (exit‑code 2 = “changes”) and applies.
- The job output prints the **ALB URL** 🌐.

---

## 🔧 Useful commands

From `infra/env/dev-ecs`:

```bash
./run.sh plan        # Terraform plan (CI treats exit code 2 as "changes", ✅)
./run.sh apply       # Terraform apply (updates task definition & service)
./run.sh outputs     # show outputs (ECR URL, cluster, service, etc.)
./run.sh url         # print ALB URL
```

From repo root (local helper; CI does this automatically):

```bash
# build/push to ECR with a custom tag
IMAGE_TAG=my-feature ./infra/env/dev-ecs/run.sh ecr-push
```

---

## 🧰 Troubleshooting

- **503 from ALB** → wrong `IMAGE_TAG` or task unhealthy.
  - Redeploy with a valid ECR tag, check ECS service events + CloudWatch logs.
- **403 in CI plan/apply** → missing read action in deploy role.
  - Re‑apply `infra/bootstrap-foundation` (policy additions).
- **Local TF asks for inputs** → export `TF_BACKEND_BUCKET` & `TF_BACKEND_DYNAMO_TABLE`.

---

## 🗺️ Roadmap

- HTTPS (ACM + 443 listener) 🔒
- Blue/Green or canary on ECS 🎛️
- WAFv2 on ALB 🛡️
- Prod/stage environments (workspaces or per‑env folders) 🌐

---

## 📜 License

MIT — see [LICENSE](LICENSE).
