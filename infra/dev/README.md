# 🧩 Dev Environment – Terraform on AWS (ECR + EC2 + Logs)

This folder (`infra/dev`) contains **application infrastructure** for a FastAPI-style service on AWS.  
It reuses the *bootstrap* remote state (S3 + DynamoDB) and deploys a minimal, secure-by-default stack you can iterate on.

---

## 🏗️ What this deploys

- **Amazon ECR (private)**  
  - Scan on push ✅  
  - AES-256 encryption at rest ✅  
  - Lifecycle policy (keep last 10 images) ✅

- **IAM for runtime (EC2)**  
  - Role + instance profile for the VM  
  - Managed policies: `AmazonEC2ContainerRegistryReadOnly`, `AmazonSSMManagedInstanceCore`  
  - Minimal CloudWatch Logs policy attached

- **Compute (EC2, Amazon Linux 2)**  
  - No SSH key; access via **AWS SSM** only  
  - IMDSv2 required  
  - Root volume encrypted  
  - **User Data**: install Docker, login ECR, pull `${account}.dkr.ecr.${region}.amazonaws.com/<repo>:<tag>`, run container with `-p 80:8000 --restart=always`

- **Networking & Logs**  
  - Security Group allowing **HTTP 80 from 0.0.0.0/0** (lab/dev purpose)  
  - CloudWatch Log Group `/fastapi/dev` (retention: **14 days**)

> ⚠️ For production, front this with an ALB + TLS (ACM), lock down security groups, and move to private subnets (see roadmap).

---

## 📦 Requirements

- **AWS CLI** (authenticated profile)  
- **Terraform** ≥ 1.6  
- **Docker** (with **Buildx**) for image build/push  
- `curl` (optional, for quick checks)

---

## 🔧 Environment variables

These drive both Terraform and helper commands in `run.sh`.

| Variable | Default | Required | Description |
|---|---:|:---:|---|
| `AWS_PROFILE` | `bootstrap` | ✓ | AWS CLI profile to use |
| `AWS_REGION` | `eu-west-3` | ✓ | Target region |
| `TF_BACKEND_BUCKET` | – | ✓ | S3 bucket name from **bootstrap** output `s3_bucket_name` |
| `TF_BACKEND_DYNAMO_TABLE` | – | ✓ | DynamoDB table from **bootstrap** output `dynamodb_table_name` |
| `AWS_ACCOUNT_ID` | – | ✓ | e.g. `aws sts get-caller-identity --query Account --output text` |
| `ECR_REPO` | `fastapi-dev` |  | ECR repository name |
| `IMAGE_TAG` | `latest` |  | Tag to deploy (`dev`, `main`, etc.) |
| `NAME_PREFIX` | `fastapi-dev` |  | Naming prefix for resources |
| `INSTANCE_TYPE` | `t3.micro` |  | EC2 instance type |
| `VPC_ID` | *(empty)* |  | If set, resources go in this VPC; otherwise default VPC |

---

## 🚀 Quickstart

From the repo root:

```bash
cd infra/dev

# --- Base config (reuse bootstrap outputs) ---
export AWS_PROFILE="bootstrap"
export AWS_REGION="eu-west-3"
export TF_BACKEND_BUCKET="tfstate-<your-handle>-euw3"         # from bootstrap
export TF_BACKEND_DYNAMO_TABLE="terraform-locks"              # from bootstrap

# --- AWS account / naming ---
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --profile "$AWS_PROFILE")
export ECR_REPO="fastapi-dev"
export IMAGE_TAG="dev"                                        # image tag to deploy

# 1) Pre-flight & backend init
./run.sh check
./run.sh init

# 2) Plan & apply infra (ECR, IAM, SG, EC2, Logs)
./run.sh plan
./run.sh apply

# 3) Build & push container (linux/amd64) from repo ROOT
./run.sh ecr-push

# 4) Recreate the instance to pull your new image tag
./run.sh ecr-redeploy

# 5) Verify
./run.sh verify              # curls the public IP
./run.sh logs                # tails CloudWatch logs
```

> 📝 If you prefer manual push: look at the output `ecr_repo_url`, then `docker login`, `docker buildx build --platform linux/amd64 -t <repo>:<tag> --push .` from the **repo root**.

---

## 🧰 Script commands

All commands are invoked as `./run.sh <command>` in `infra/dev`.

- `check` – pre-flight checks (CLI tools, AWS auth, required env)  
- `init` – initialize the Terraform backend (**S3/DynamoDB**) using bootstrap outputs  
- `plan` – `terraform plan` with variables from your env  
- `apply` – applies the infrastructure  
- `outputs` – prints Terraform outputs  
- `destroy` – destroys the environment created by this stack  
- `local-clean` – removes local Terraform files (`.terraform`, `tfstate*`, lockfile)  
- `ecr-push` – builds **linux/amd64** image from repo root and **pushes to ECR**  
- `ecr-redeploy` – taints the EC2 instance to force recreation (pulling the new image)  
- `verify` – curls the public IP (`/`) to verify the app answers on port 80  
- `logs` – tails the CloudWatch Log Group for the app

---

## 📤 Terraform outputs

After `apply`, you’ll get these outputs:

- `ecr_repo_url` – `ACCOUNT.dkr.ecr.REGION.amazonaws.com/<repo>`  
- `instance_public_ip` – public IP of the EC2 instance  
- `instance_id` – EC2 instance ID  
- `security_group_id` – Security Group ID  
- `log_group_name` – CloudWatch Log Group (`/fastapi/dev`)

---

## 🧪 Verifications (manual)

```bash
# IP & Logs
IP=$(terraform output -raw instance_public_ip)
curl -i "http://$IP/"
aws logs tail $(terraform output -raw log_group_name) --since 10m --follow \
  --region "$AWS_REGION" --profile "$AWS_PROFILE"
```

If you enabled SSM, you can also open a session to the instance to inspect Docker runtime:

```bash
aws ssm start-session --target "$(terraform show -json | jq -r '.values.root_module.resources[] | select(.address=="aws_instance.api").values.id')" \
  --region "$AWS_REGION" --profile "$AWS_PROFILE"
# then on the instance:
#   sudo docker ps
#   sudo docker logs <container>
```

---

## 🩺 Troubleshooting

- **`curl` can’t connect / timeout**  
  - Give it ~60s after instance creation (User Data pulls image, starts container).  
  - Confirm SG allows ingress on TCP 80 from your IP (`0.0.0.0/0` in this template).  
  - Check container status via SSM session: `docker ps` and `docker logs <container>`.

- **`exec format error` in logs**  
  - Your host built an ARM image; EC2 is x86_64.  
  - Use the helper: `./run.sh ecr-push` (builds `linux/amd64`) or manually:  
    `docker buildx build --platform linux/amd64 -t <repo>:<tag> --push .`

- **ECR repo already exists**  
  - If created outside Terraform, either import it or delete it before `apply`.  
  - This template expects Terraform to own the repository.

- **Terraform init shows “Missing backend configuration” warning**  
  - Harmless here because the script passes `-backend-config` flags.  
  - To silence it, add a minimal block in your TF config:
    ```hcl
    terraform { backend "s3" {} }
    ```

---

## 📁 File layout (key files)

- `ecr.tf` – ECR repo + lifecycle policy  
- `iam_runtime.tf` – EC2 role/profile + policy attachments  
- `network.tf` – Security Group (HTTP 80)  
- `compute.tf` – EC2 instance + user data (Docker run)  
- `logs.tf` – CloudWatch Log Group  
- `variables.tf` – Variables (region, repo, image tag, names, etc.)

---

## 🔒 Security & next steps

- Current SG exposes port **80** to the world → suitable for **dev/lab** only.  
- Consider next iterations:
  - Dedicated **VPC** (public/private subnets + NAT)
  - **ALB** + **TLS (ACM)** + optional **WAF**
  - ECS/Fargate or ASG rolling deploys
  - KMS for ECR/S3 keys if compliance requires
  - Centralized logs/metrics/alerts

---

## 💸 Cost note

Small but non-zero AWS costs (EC2, ECR storage, CloudWatch logs). Destroy environments you’re not using.

---

## ✅ One-liner sanity check

```bash
./run.sh check && ./run.sh init && ./run.sh plan
```

Then: `./run.sh apply` → `./run.sh ecr-push` → `./run.sh ecr-redeploy` → `./run.sh verify`.
