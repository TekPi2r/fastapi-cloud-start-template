```bash
# Requiert le backend S3 + Dynamo créés par bootstrap-state
export AWS_PROFILE="bootstrap"
export AWS_REGION="eu-west-3"

export TF_BACKEND_BUCKET="tfstate-<handle>-euw3"   # unique global utilisé dans bootstrap-create
export TF_BACKEND_DYNAMO_TABLE="terraform-locks"

export GITHUB_OWNER="TekPi2r"
export GITHUB_REPO="fastapi-cloud-start-template"
export ALLOWED_BRANCHES="main"            # éventuellement: "main,release/*"

# Optionnel: autoriser des rôles d’équipe (break-glass)
# export TRUSTED_ROLE_ARNS="arn:aws:iam::<acct>:role/engineering-admin"
export TRUSTED_ROLE_ARNS=""

./run.sh init
./run.sh plan
./run.sh apply
./run.sh outputs
```