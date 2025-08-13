# Project History

## 1️⃣ Version 1.0.0 - Initial Setup (2025-08-08)

### ✅ Backend Features
- Initialized project with **FastAPI**
- Created basic endpoints:
  - `GET /health` – Health check
  - `POST /items` & `GET /items` – Simple CRUD
- Used **Pydantic v2** for request/response models

### 🧪 Testing
- Integrated **pytest**
- Wrote unit tests for:
  - Health check endpoint
  - Item creation and retrieval
- MongoDB mocked for local tests
- Tests run successfully both locally and in CI

### 🧹 Code Quality
- Configured **ruff** for linting
- Enabled **auto-fix** with `ruff --fix`
- Added linting to GitHub Actions (CI fails on lint errors)

### ⚙️ DevOps & Tooling
- Added `Dockerfile` for containerized deployment
- Created `docker-compose.yml` with:
  - FastAPI app
  - MongoDB service
- Environment managed via `.env` and `python-dotenv`
- Set up Python virtual environment `.venv`

### 🔄 CI/CD
- Added **GitHub Actions workflow** with:
  - Service container for MongoDB
  - Test job using `pytest`
  - Lint job using `ruff`
  - MongoDB health check before running tests

---

## Next Steps (planned)
- Add **Trivy** to scan Docker images
- Possibly integrate **type checking** (`mypy` or `pyright`)
- Prepare for deployment (Azure, AWS, or other)
- Write full `README.md`





## 2️⃣ Version 2.0.0 - Kubernetes and CI overhaul (2025-08-11)

- Switched to Alpine Docker image, non-root user, and healthcheck.
- Added Kubernetes manifests (API + Mongo, ConfigMap/Secret, probes).
- Introduced Makefile with handy targets: `dev`, `tests`, `tests-integration`, `logs`, `clean`.
- Split pytest into unit vs integration with markers and `pytest.ini` env.
- Added GitHub Actions pipeline: unit & integration jobs; Mongo as a service for integration.
- Wired secrets/config: `.env` (optional), `pytest.ini` (CI), `k8s/secret.yaml` + `k8s/config.yaml` (cluster).
- Documented Trivy usage for image scanning.





## 3️⃣ Version 3.0.0 – AWS Terraform bootstrap & dev infra (2025-08-13)

### ✨ Highlights
- End-to-end **AWS infrastructure** with Terraform:
  - **Bootstrap**: remote state on **S3** + state locks in **DynamoDB**
  - **Dev**: **ECR** repository, **EC2** runner, **CloudWatch Logs**, **Security Group**
- New developer **run scripts** with rich UX, checks, and one-liners to deploy, push image, redeploy, and destroy safely.

### 🏗️ Infrastructure as Code
- **Bootstrap (infra/bootstrap)**
  - S3 state bucket with versioning, server-side encryption (AES256), public access block, lifecycle for incomplete uploads.
  - DynamoDB table `terraform-locks` for state locking.
  - Outputs: `s3_bucket_name`, `dynamodb_table_name`.

- **Dev (infra/dev)**
  - **ECR** repo (lifecycle: keep last 10 images).
  - **EC2** (Amazon Linux 2, `t3.micro`, default VPC) with **IAM role + instance profile**:
    - Managed policies: `AmazonSSMManagedInstanceCore`, `AmazonEC2ContainerRegistryReadOnly`.
    - Minimal custom policy for CloudWatch Logs.
  - **CloudWatch Log Group** `/fastapi/dev` (retention 14 days).
  - **Security Group** `fastapi-dev-sg` – inbound **80/tcp** (world), egress all.
  - **User data**: installs Docker, logs into ECR, pulls image `repo:tag`, runs container mapping **80 → 8000**.
  - Terraform outputs: `ecr_repo_url`, `instance_id`, `instance_public_ip`, `security_group_id`, `log_group_name`.

### 🧰 Dev Runner Scripts
- **infra/bootstrap/run.sh**
  - `check`, `check-clean`, `init`, `plan`, `apply`, `destroy`, `outputs`, `local-clean`.
- **infra/dev/run.sh**
  - `check`, `init`, `plan`, `apply`, `outputs`, `destroy`, `status`, `logs`, `hit`, `redeploy`, `ecr-login`, `ecr-push`, `local-clean`.
  - Preflight verifies AWS auth, backend env, optional `jq`, and can auto-detect `AWS_ACCOUNT_ID`.
  - `ecr-push` builds **linux/amd64** with **docker buildx** from repo root (Dockerfile at project root).

### 🚀 Typical Workflow
```bash
# Bootstrap remote state
cd infra/bootstrap
./run.sh apply
./run.sh outputs  # get BUCKET + TABLE

# Deploy dev infra
cd ../dev
export AWS_PROFILE=bootstrap
export AWS_REGION=eu-west-3
export TF_BACKEND_BUCKET=<from bootstrap>
export TF_BACKEND_DYNAMO_TABLE=<from bootstrap>
./run.sh apply

# Build & push image, then redeploy EC2 to pull it
./run.sh ecr-push
./run.sh redeploy

# Smoke test + logs
./run.sh hit
./run.sh logs
```

### 🧹 Safe Destroy (with ECR purge)
- `./run.sh destroy` now **empties the ECR repo first** (server-side purge) to avoid `RepositoryNotEmptyException`, then deletes infra.
- `./run.sh local-clean` clears local Terraform artifacts without touching AWS.

### 🛠️ Troubleshooting Notes
- `exec format error` when the instance starts the container → fixed by building/pushing **linux/amd64** images via `ecr-push`.
- “Missing backend configuration” warning → optional: add `terraform { backend "s3" {} }` in `providers.tf`.
- Duplicate resources after previous manual runs (SG/Role/LogGroup already exists) → use the provided **cleanup/destroy** flow (purge ECR, then `destroy`) and re-`apply`.

