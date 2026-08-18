# Terraform Decisions

## 1. Remote State and Bootstrap

### Decision

Use a dedicated Terraform bootstrap configuration to create the
remote state infrastructure.

### Resources

- Amazon S3 bucket:
  `devops-lab-2026-terraform-state-arslan`
- DynamoDB table:
  `devops-lab-terraform-lock`

### Main Terraform State

The main Terraform configuration uses:

- S3 bucket for remote state
- Key: `devops-lab/terraform.tfstate`
- Region: `ap-south-1`
- Encryption enabled
- S3 native lockfile enabled

### Verification

- Bootstrap Terraform initialized successfully.
- Bootstrap configuration validated successfully.
- Main Terraform backend initialized successfully.
- Main Terraform configuration validated successfully.

### Status

Completed.

---

## 2. VPC

### Decision

Use a dedicated Terraform VPC module for the AWS network boundary.

### Configuration

- VPC CIDR: `10.0.0.0/16`
- Public subnet: `10.0.1.0/24`
- Private subnet: `10.0.2.0/24`

### Reason

The architecture requires a public network segment for the bastion
host and a private network segment for the application server.

### Terraform Module

`terraform/modules/vpc/`

### Status

In progress.
