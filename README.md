# 🚀 FastAPI Cloud Start Template

[![CI](https://github.com/TekPi2r/fastapi-cloud-start-template/actions/workflows/ci.yml/badge.svg)](https://github.com/TekPi2r/fastapi-cloud-start-template/actions) [![Trivy](https://github.com/TekPi2r/fastapi-cloud-start-template/actions/workflows/trivy.yml/badge.svg)](https://github.com/TekPi2r/fastapi-cloud-start-template/actions) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE) ![Python](https://img.shields.io/badge/python-3.11-blue.svg) ![FastAPI](https://img.shields.io/badge/FastAPI-0.116.1-green.svg) ![Kubernetes](https://img.shields.io/badge/Kubernetes-local--dev-blueviolet.svg)

A modern production-ready **FastAPI** template, now with a turnkey **AWS infra path** (Terraform S3/DynamoDB backend, ECR, EC2, CloudWatch) and a streamlined **Run script UX**. Build locally on Kubernetes, or deploy a dev environment in minutes on AWS.

---

## ✨ What’s Inside

- **API & Auth**
  - 🔐 OAuth2 password flow with **JWT**
  - ⚡ FastAPI + Uvicorn
- **Data & Tests**
  - 🍃 **MongoDB** (Docker/K8s)
  - 🧪 **pytest** with `unit` & `integration` markers
- **Containers & Security**
  - 🐳 Alpine-based **Dockerfile**, non-root, healthcheck
  - 🛡️ **Trivy** image scanning (locally & in CI)
- **CI/CD**
  - 🤖 **GitHub Actions** (tests + security)
- **Local Dev**
  - ☸️ **Kubernetes/Minikube** workflow via `make`
- **AWS Infra (NEW)**
  - 🧱 `infra/bootstrap`: **Terraform remote state** (S3 + DynamoDB) + helper `run.sh`
  - 🛠️ `infra/dev`: **ECR** repo, **EC2** runner (pulls & runs your image), **CloudWatch Logs**, **IAM** (ECR RO + SSM), **Security Group** for `:80 → 8000`
  - 🧩 Dev `run.sh` with: `check/init/plan/apply/outputs/destroy/status/logs/hit/redeploy/ecr-login/ecr-push/local-clean`
  - 📦 **Multi-arch push** to ECR with `docker buildx` (`linux/amd64`), then **EC2 redeploy** (recreate) to pick the new image
  - 🧹 Safe destroy: helper empties ECR repo images before deleting resources

---

## 🗺️ Architecture

```text
Local
┌────────────────────┐      ┌───────────┐
│ FastAPI (Uvicorn) │◄────►│ MongoDB   │
│ OAuth2 + JWT      │      │ (Docker)  │
└────────────────────┘      └───────────┘
       ▲     ▲
       │     └── pytest / CI / Trivy

AWS Dev
┌───────────┐   push (buildx)   ┌─────────┐    user_data     ┌──────────┐
│ Developer │ ────────────────► │  ECR    │ ───────────────► │  EC2     │
└───────────┘                   └─────────┘                  │  Docker  │
                              logs ◄─────────────────────────│  App 8000│
                                      CloudWatch Logs        └──────────┘
```

---

## 🚀 Quick Start

### 1) Local Dev (Kubernetes)
```bash
make dev          # build image, load into Minikube, apply manifests, show service URL
make logs         # follow API logs
make tests        # all tests
make tests-int    # integration tests only
```

### 2) Bootstrap AWS Remote State (once)
```bash
cd infra/bootstrap
export AWS_PROFILE="bootstrap"
export AWS_REGION="eu-west-3"
export BUCKET_NAME="tfstate-<your-handle>-euw3"   # must be globally unique

./run.sh check
./run.sh apply
./run.sh outputs   # grab s3_bucket_name + dynamodb_table_name
```

### 3) Provision Dev Infra (ECR + EC2 + Logs)
```bash
cd ../dev
export AWS_PROFILE="bootstrap"
export AWS_REGION="eu-west-3"
export TF_BACKEND_BUCKET="<s3_bucket_name from bootstrap>"
export TF_BACKEND_DYNAMO_TABLE="terraform-locks"
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --profile "$AWS_PROFILE")
# optional overrides
export ECR_REPO="fastapi-dev"
export IMAGE_TAG="dev"

./run.sh apply     # creates ECR, EC2, IAM, SG, CloudWatch
./run.sh outputs
```

### 4) Build & Push Image to ECR (linux/amd64) and Redeploy
```bash
./run.sh ecr-push  # multi-arch push from project root (auto-detected)
./run.sh redeploy  # recreate EC2 to pull the new image
./run.sh hit       # curl http://<public-ip>/
./run.sh logs      # tail CloudWatch Logs
```

### 5) Destroy (safe)
```bash
./run.sh destroy   # empties ECR images then terraform destroy
```

> Tip: `./run.sh status` gives a quick health report (outputs, ECR existence, basic HTTP reachability).

---

## 🧩 Project Layout

```
.
├── app/                        # FastAPI app
├── Dockerfile                  # Non-root, production-ready
├── k8s/                        # Local K8s manifests
├── infra/
│   ├── bootstrap/              # Terraform S3 + DynamoDB (remote state)
│   │   ├── run.sh              # check/init/plan/apply/.../local-clean
│   │   └── *.tf
│   └── dev/                    # Terraform Dev stack (ECR/EC2/Logs/IAM/SG)
│       ├── run.sh              # rich UX: ecr-push, redeploy, logs, hit, ...
│       ├── user_data.sh.tftpl  # EC2 startup (Docker login + run)
│       └── *.tf
├── Makefile                    # Local dev helpers
└── README.md                   # This file
```

---

## 🧪 Testing

```bash
pytest -m unit -v
pytest -m integration -v
```

---

## 🔐 Secrets Management

- Local dev → `.env` via Pydantic settings
- Kubernetes → `config.yaml` / `secret.yaml`
- CI/CD → GitHub Actions env & secrets

---

## 🧰 Useful Commands

**Trivy scan (local):**
```bash
trivy image fastapi-template:latest
```

**Query ECR images:**
```bash
aws ecr describe-images --repository-name fastapi-dev   --query "imageDetails[].imageTags" --output json   --region "$AWS_REGION" --profile "$AWS_PROFILE"
```

**Curl the dev EC2:**
```bash
cd infra/dev
IP=$(terraform output -raw instance_public_ip)
curl -i "http://$IP/"
```

---

## 🛠️ Troubleshooting

- 🐳 `exec format error` in logs (CloudWatch): build for the correct target.
  ```bash
  ./run.sh ecr-push   # uses docker buildx --platform linux/amd64
  ./run.sh redeploy
  ```

- ⚠️ Terraform backend warning:
  - You can keep the script-based backend config, or add this in `providers.tf` to silence the warning:
    ```hcl
    terraform { backend "s3" {} }
    ```

- 🧹 Destroy fails with `RepositoryNotEmptyException`:
  - Use `./run.sh destroy` (it empties ECR images before deleting the repo).

---

## 📜 License

MIT License. See [LICENSE](LICENSE).
