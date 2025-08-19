```bash
export AWS_PROFILE="bootstrap"
export AWS_REGION="eu-west-3"
export TF_BACKEND_BUCKET="tfstate-pi2r-devsecops-project-euw3"
export TF_BACKEND_DYNAMO_TABLE="terraform-locks"

export NAME_PREFIX="fastapi"
export IMAGE_TAG="latest-dev"

./run.sh plan
./run.sh apply
./run.sh ecr-push            # buildx amd64 + push :dev
./run.sh apply               # (si IMAGE_TAG a changé, enregistre un nouveau task def et déploie)
./run.sh url                 # donne l’URL ALB
```