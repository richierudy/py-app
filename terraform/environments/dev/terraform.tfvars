aws_region         = "us-east-1"
app_name          = "python-cicd-app"
vpc_id            = "vpc-xxxxx"
private_subnet_ids = ["subnet-xxxxx", "subnet-yyyyy"]
public_subnet_ids  = ["subnet-aaaaa", "subnet-bbbbb"]
image_tag         = "latest"
slack_webhook_url = "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"

common_tags = {
  Project     = "Python CI/CD"
  ManagedBy   = "Terraform"
  Owner       = "DevOps Team"
}
