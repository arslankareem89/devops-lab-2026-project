# Cloud DevOps Lab 2025

A hands-on DevOps project where I am building a small application environment on AWS and learning how the different parts work together.

The project is being built step by step, starting with Git and GitHub and moving towards infrastructure, application deployment, CI/CD, security, monitoring, and operations.

## Project Flow

```
Developer → GitHub → Jenkins → Build → Test → SonarQube → Docker Build → Deploy → AWS
```

The AWS environment contains a public subnet with a Bastion Host and a private subnet with the Application Server. The private server uses the NAT Gateway for required outbound internet access.

## Technology Stack

- Git
- GitHub
- AWS
- Terraform
- Ansible
- Docker
- Docker Compose
- Nginx
- Flask
- Jenkins
- SonarQube
- PostgreSQL
- Prometheus
- Grafana
- CloudWatch
- AWS Systems Manager

## AWS Infrastructure

Terraform is used to provision and manage the AWS infrastructure.

The environment includes:

- VPC
- Public and private subnets
- Internet Gateway
- NAT Gateway
- Elastic IP
- Route tables
- Bastion EC2 instance
- Application EC2 instance
- Security Groups
- IAM roles and policies
- S3
- DynamoDB
- CloudWatch
- Systems Manager

## Configuration Management

Ansible is used to configure the EC2 servers after the infrastructure is provisioned.

This includes server packages, users, permissions, SSH configuration, Docker installation, application configuration, and service configuration.

Sensitive configuration is handled using Ansible Vault and AWS SSM.

## Application

The project contains a Flask application with automated tests.

The application runs inside Docker and is accessed through Nginx.

```
Client → Nginx → Flask Application → Supporting Services
```

## CI/CD

Jenkins is used to automate the application delivery process.

```
GitHub → Jenkins → Checkout → Build → Test → SonarQube Analysis → Quality Gate → Docker Build → Push Image → Deploy
```

## Monitoring & Observability

Monitoring and observability are included to understand the health and behaviour of both the application and infrastructure.

The project covers:

- Application health
- Container health
- EC2 resources
- CPU and memory
- Disk usage
- Network activity
- Service availability
- Application and system logs
- Metrics
- Dashboards
- Alerts

Prometheus and Grafana are used for metrics and dashboards, while CloudWatch is used for AWS-level monitoring, logs, and alarms.

## Security

Security is considered throughout the project.

The environment uses:

- Private subnet for the application server
- Bastion Host for controlled access
- Security Groups
- IAM roles and policies
- AWS Systems Manager
- Restricted network access
- SSH hardening
- Ansible Vault
- SSM Parameter Store
- Protected GitHub branches
- No credentials or private keys committed to Git

## Development Workflow

Development follows a Git-based workflow.

```
Feature/Fix → dev → Pull Request → main
```

GitHub Issues, Pull Requests, branch protection, and a Kanban board are used to manage the work.

## Infrastructure Lifecycle

AWS resources are created only when they are required for development or testing.

```bash
terraform plan
terraform apply
terraform destroy
```

The environment is destroyed when it is no longer required to avoid unnecessary AWS costs.

## Getting Started

**Prerequisites:** AWS credentials configured, Terraform >= 1.5, Ansible >= 2.14, Docker, Python 3.10+

```bash
git clone https://github.com/<your-username>/cloud-devops-lab-2025.git
cd cloud-devops-lab-2025

# 1. Provision infrastructure
cd terraform
terraform init
terraform apply

# 2. Configure the servers
cd ../ansible
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --ask-vault-pass

# 3. Start services
cd ../docker
docker compose up -d
```

## Project Phases

1. Git & Project Setup
2. Flask Application
3. AWS Networking
4. AWS Compute & Security
5. Terraform Modules
6. Ansible
7. Docker & Docker Compose
8. Nginx
9. CI/CD
10. Monitoring & Observability
11. Security Review
12. Final Integration & Operations

Each phase is implemented, tested, and documented before moving to the next phase.

## Project Status

- [x] Phase 1 — Git & Project Setup
- [ ] Phase 2 — Flask Application
- [ ] Phase 3 — AWS Networking
- [ ] Phase 4 — AWS Compute & Security
- [ ] Phase 5 — Terraform Modules
- [ ] Phase 6 — Ansible
- [ ] Phase 7 — Docker & Docker Compose
- [ ] Phase 8 — Nginx
- [ ] Phase 9 — CI/CD
- [ ] Phase 10 — Monitoring & Observability
- [ ] Phase 11 — Security Review
- [ ] Phase 12 — Final Integration & Operations

## Project Goal

The goal of this project is not only to make the environment work, but to understand why each piece exists, how it connects to the rest of the system, and how to troubleshoot it when something breaks.
