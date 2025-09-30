# Composition is organised across dedicated files by domain:
# - locals.tf         shared naming and tagging
# - providers.tf      provider + backend
# - data.tf           data sources referencing shared foundation resources
# - network.tf        VPC discovery, security groups, VPC endpoints
# - alb.tf            Application Load Balancer + access logs bucket
# - ecs.tf            ECS cluster, task and service definitions
# - iam_task*.tf      Task execution/runtime roles
# - kms.tf            KMS keys for logs and ALB access logs bucket
# - logs.tf           CloudWatch log groups and alarms
# - autoscaling.tf    ECS Application Auto Scaling policies
