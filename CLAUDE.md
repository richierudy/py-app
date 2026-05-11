# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

**Setup:**
```bash
python3 -m venv venv
. venv/bin/activate
pip install -r app/requirements.txt
```

**Run app locally:**
```bash
python app/main.py   # dev server on port 8080
```

**Run tests:**
```bash
pytest tests/ -v
pytest tests/test_main.py::test_health_endpoint  # single test
```

**Lint:**
```bash
flake8 app/ --max-line-length=120
pylint app/*.py
```

**Docker:**
```bash
docker build -t python-cicd-app .
docker run -p 8080:8080 -e ENVIRONMENT=local python-cicd-app
```

**Terraform (per environment):**
```bash
cd terraform/environments/dev
terraform init
terraform plan -var="image_tag=<tag>"
terraform apply -var="image_tag=<tag>"
```

## Architecture

This is a Flask web app designed to run on AWS ECS Fargate, built and deployed via a Jenkins CI/CD pipeline.

**Application (`app/`):** A minimal Flask app exposing two endpoints — `GET /` (welcome) and `GET /health` — both reading `ENVIRONMENT` and `APP_VERSION` from env vars. Served in production by gunicorn with 4 workers on port 8080.

**CI/CD pipeline (`Jenkinsfile`):** Jenkins pipeline with these sequential stages: checkout → install deps → pytest → flake8/pylint → Docker build → Snyk container scan → push to ECR (tagged with build number, short git SHA, and `latest`) → deploy to dev → optional UAT (gated by `DEPLOY_TO_UAT` param + human approval) → optional prod (gated by `DEPLOY_TO_PROD` param + human approval, `admin,release-manager` only). Deployments run `terraform apply` then force an ECS service redeployment and wait for stabilization. Smoke tests poll `GET /health` via the ALB DNS (10 retries, 10s apart). The Snyk stage requires a Jenkins credential named `snyk-token` (Secret text) and `snyk` CLI installed on the agent.

**Infrastructure (`terraform/`):** Four reusable modules composed per environment, with three environments (`dev`, `uat`, `prod`) each in their own directory under `terraform/environments/`:
- `modules/networking` — VPC, Internet Gateway, 2 public + 2 private subnets across 2 AZs, NAT Gateway (single, in first public subnet), and route tables. All other modules consume its outputs (`vpc_id`, `public_subnet_ids`, `private_subnet_ids`).
- `modules/ecr` — ECR repo with scan-on-push and a lifecycle policy retaining the last 10 images.
- `modules/ecs` — Fargate cluster + service behind a public ALB on port 80 → 8080. Tasks run in private subnets and reach ECR/internet via the NAT Gateway. CloudWatch Logs at `/ecs/<env>/<app>` (30-day retention). Two IAM roles: execution role (ECR/CloudWatch access) and task role (app permissions). Task sizing varies by environment: dev 256 CPU/512 MB×2, uat 512 CPU/1024 MB×2, prod 1024 CPU/2048 MB×4.
- `modules/lambda` — Python 3.11 Lambda (`lambda-deployment.py` in repo root) triggered by EventBridge on `ECS Deployment State Change` events; posts formatted Slack notifications via `SLACK_WEBHOOK_URL`.

Each environment has its own VPC CIDR (dev `10.0.0.0/16`, uat `10.1.0.0/16`, prod `10.2.0.0/16`) and isolated S3 state key (`dev/`, `uat/`, `prod/`). State bucket is `rphillips110-terraform-state-bucket` with DynamoDB table `rphillips110-terraform-state-lock`. Update `slack_webhook_url` in each `terraform.tfvars` before deploying.

**Key env vars at runtime:** `ENVIRONMENT`, `APP_VERSION` (app); `SLACK_WEBHOOK_URL`, `ENVIRONMENT` (Lambda).
