```bash
export AWS_PROFILE="bootstrap"
export AWS_REGION="eu-west-3"
export BUCKET_NAME="tfstate-<handle>-euw3"   # unique global

# (optionnel)
export DYNAMO_TABLE="terraform-locks"
export NAME_PREFIX="fastapi"
export ENVIRONMENT="bootstrap"

./run.sh check
./run.sh init
./run.sh plan
./run.sh apply
./run.sh outputs
```