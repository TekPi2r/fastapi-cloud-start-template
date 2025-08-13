# 🚀 Terraform Bootstrap Infrastructure

This directory (`infra/bootstrap`) contains Terraform code to set up the **remote state backend** for your project.

It will create:
- An **S3 bucket** (for Terraform state storage)
- A **DynamoDB table** (for Terraform state locking)

---

## 📦 Requirements
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) configured with an IAM user with admin rights.
- [Terraform](https://developer.hashicorp.com/terraform/downloads) installed (>= 1.6.0).
- AWS profile configured (default: `bootstrap`).

---

## ⚙️ Environment Variables

| Variable            | Default            | Description |
|--------------------|--------------------|-------------|
| `BUCKET_NAME`      | *(required)*       | Globally unique S3 bucket name for storing the Terraform state |
| `AWS_PROFILE`      | `bootstrap`        | AWS CLI profile name |
| `AWS_REGION`       | `eu-west-3`        | AWS region for resources |
| `DDB_TABLE`        | `terraform-locks`  | DynamoDB table name for state locking |
| `SSE_KMS_KEY_ARN`  | *(empty → AES256)* | **Optional**. If set, the S3 state bucket uses **SSE-KMS** with this key; otherwise **SSE-S3 (AES256)** is enforced |

---

## 📜 Usage

### 1️⃣ Set your environment variables
```bash
export BUCKET_NAME="tfstate-yourhandle-euw3"   # must be globally unique
export AWS_PROFILE="bootstrap"
export AWS_REGION="eu-west-3"
# Optional: use KMS instead of AES256
# export SSE_KMS_KEY_ARN="arn:aws:kms:eu-west-3:<account-id>:key/<key-id>"
```

### 2️⃣ Check pre-requisites
```bash
./run.sh check
```

### 3️⃣ Check if AWS bootstrap resources already exist
*(Useful before re-running `apply`)*
```bash
./run.sh check-clean
```
> Tip: `check-clean` also warns if the bucket name exists **in another account** (choose a different `BUCKET_NAME`).

### 4️⃣ Initialize backend
```bash
./run.sh init
```

### 5️⃣ Plan infrastructure changes
```bash
./run.sh plan
```

### 6️⃣ Apply infrastructure creation
```bash
./run.sh apply
```

### 7️⃣ View outputs
```bash
./run.sh outputs
```

### 8️⃣ Destroy infrastructure
```bash
./run.sh destroy
```

## 🧹 Local cleanup (safe reset)
```bash
./run.sh local-clean
```

Use this command to remove **local Terraform files** in this folder when you want a fresh init.

What it deletes:
- `.terraform/`
- `.terraform.lock.hcl`
- `*.tfstate` and `*.tfstate.backup`
- `override.tf`, `override.tf.json`, `*_override.tf`, `*_override.tf.json`
- `crash.log`

⚠️ **This does NOT destroy any AWS resources.**  
You'll be prompted to type `yes` before anything is deleted.

---

## 🔐 What Terraform creates (security highlights)
- **S3 bucket (state)** with:
  - **Versioning** enabled
  - **Server-Side Encryption** enforced: `AES256` by default, or **KMS** if `SSE_KMS_KEY_ARN` is provided
  - **Public Access Block**: all public access fully blocked
  - **Bucket Policy**:
    - Deny any request **not using TLS** (`DenyInsecureTransport`)
    - Deny any `PutObject` **without SSE header** (AES256 or aws:kms)
  - **Lifecycle**: abort incomplete multipart uploads after 7 days
  - **Ownership controls**: `BucketOwnerEnforced` (no ACLs)
- **DynamoDB table** (`LockID` hash key) for **state locking** (billing `PAY_PER_REQUEST`)
- **Tags** applied on all resources: `Name`, `Environment`, `ManagedBy`

---

## 🧪 Quick security checks (optional)
After `apply`, you can verify:

```bash
# Who am I?
aws sts get-caller-identity --profile "$AWS_PROFILE"

# Encryption on the bucket
aws s3api get-bucket-encryption --bucket "$BUCKET_NAME" --profile "$AWS_PROFILE"

# Block Public Access (should all be true)
aws s3api get-public-access-block --bucket "$BUCKET_NAME" --profile "$AWS_PROFILE"

# Policy test: SSE required
echo "hello" > /tmp/obj.txt
# Should SUCCEED (explicit SSE)
aws s3api put-object --bucket "$BUCKET_NAME" --key test-ok.txt --body /tmp/obj.txt   --server-side-encryption AES256 --profile "$AWS_PROFILE"
# Should FAIL (no SSE header)
aws s3api put-object --bucket "$BUCKET_NAME" --key test-ko.txt --body /tmp/obj.txt   --profile "$AWS_PROFILE" || echo "✅ denied as expected (missing SSE)"
```

---

## 🔄 Idempotency & re-runs
- You can **re-run `plan`/`apply`** safely: Terraform will detect no changes if resources already match the configuration.
- `destroy` removes the S3 bucket **only if empty**; Terraform handles the proper deletion order.

---

## 📤 Outputs & next step (`infra/dev`)
On `apply`, you’ll get:
- `s3_bucket_name` → use as `TF_BACKEND_BUCKET` in `infra/dev`
- `dynamodb_table_name` → use as `TF_BACKEND_DYNAMO_TABLE` in `infra/dev`

Example for `infra/dev/run.sh`:
```bash
export TF_BACKEND_BUCKET="tfstate-yourhandle-euw3"
export TF_BACKEND_DYNAMO_TABLE="terraform-locks"
```

---

## 🧭 Naming conventions (recommended)
- `tfstate-<handle>-<project>-<region>` (e.g., `tfstate-pi2r-devsecops-project-euw3`)
- Keep names **lowercase**, numbers, hyphens or dots only; must not look like an IP.

---

## 🧩 Provider/version notes
- Tested with **Terraform ≥ 1.6** and **AWS provider v5**.
- Lifecycle rule requires an explicit empty `filter {}` block in provider v5 (already included).

---

## 🆘 Troubleshooting

**`InvalidAccessKeyId` or `InvalidClientTokenId` (AWS CLI)**
- Ensure you’re using the intended profile:
  ```bash
  aws sts get-caller-identity --profile "$AWS_PROFILE"
  ```
- If you use **SSO**:
  ```bash
  aws sso login --profile "$AWS_PROFILE"
  ```
- Make sure no environment variables are overriding credentials:
  ```bash
  env | grep ^AWS_ || true
  # if present and unexpected:
  unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
  ```
- You can also force the profile inline:
  ```bash
  AWS_PROFILE="$AWS_PROFILE" aws s3api get-bucket-encryption --bucket "$BUCKET_NAME"
  ```

**`BucketAlreadyOwnedByYou` / `BucketAlreadyExists`**
- Choose a different `BUCKET_NAME` (S3 names are global), or run `destroy` if it’s yours and you want a clean slate.
- `check-clean` will warn when the name is taken (even in another account).
