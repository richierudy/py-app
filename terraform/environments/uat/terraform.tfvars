aws_region           = "us-east-1"
app_name             = "python-cicd-app"
vpc_cidr             = "10.1.0.0/16"
public_subnet_cidrs  = ["10.1.1.0/24", "10.1.2.0/24"]
private_subnet_cidrs = ["10.1.10.0/24", "10.1.11.0/24"]
availability_zones   = ["us-east-1a", "us-east-1b"]
image_tag            = "latest"
slack_webhook_url    = "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"

common_tags = {
  Project     = "Python CI/CD"
  ManagedBy   = "Terraform"
  Owner       = "DevOps Team"
}
