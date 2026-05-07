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

**CI/CD pipeline (`Jenkinsfile`):** Jenkins pipeline with these sequential stages: checkout → install deps → pytest → flake8/pylint → Docker build → Trivy image security scan → push to ECR (tagged with build number, short git SHA, and `latest`) → deploy to dev → optional UAT (gated by `DEPLOY_TO_UAT` param + human approval) → optional prod (gated by `DEPLOY_TO_PROD` param + human approval, `admin,release-manager` only). Deployments run `terraform apply` then force an ECS service redeployment and wait for stabilization. Smoke tests poll `GET /health` via the ALB DNS (10 retries, 10s apart).

**Infrastructure (`terraform/`):** Three reusable modules composed per environment:
- `modules/ecr` — ECR repo with scan-on-push and a lifecycle policy retaining the last 10 images.
- `modules/ecs` — Fargate cluster + service (2 tasks in dev, private subnets) behind a public ALB on port 80 → 8080. CloudWatch Logs at `/ecs/<env>/<app>` (30-day retention). Two IAM roles: execution role (ECR/CloudWatch access) and task role (app permissions).
- `modules/lambda` — Python 3.11 Lambda (`lambda-deployment.py` in repo root) triggered by EventBridge on `ECS Deployment State Change` events; posts formatted Slack notifications via webhook URL from env var `SLACK_WEBHOOK_URL`.

Terraform state is stored in S3 (`my-terraform-state-bucket`) with DynamoDB locking. The `terraform.tfvars` in `terraform/environments/dev/` contains placeholder values (VPC IDs, subnet IDs, webhook URL) that must be updated for a real deployment.

**Key env vars at runtime:** `ENVIRONMENT`, `APP_VERSION` (app); `SLACK_WEBHOOK_URL`, `ENVIRONMENT` (Lambda).
