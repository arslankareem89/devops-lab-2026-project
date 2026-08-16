DevOps Lab 2026 — Phase 2 Implementation Record

1. Phase 2 objective

Phase 2 was about building the AWS infrastructure required to run the application securely.

The implementation order was:

VPC and subnets

Internet Gateway, NAT Gateway and routing

Security Groups

IAM role and instance profile

Bastion and application EC2 instances

Terraform outputs and verification

This order matters because each later layer depends on the previous layer.

2. Phase 2 requirements

The project requirements were:

Create a VPC with a CIDR block.

Create a public subnet for the bastion host.

Create a private subnet for the application server.

Configure an Internet Gateway.

Configure a NAT Gateway.

Provision two EC2 instances:

Bastion host

Application server

Store Terraform state in S3 and enable state locking with DynamoDB.

Define Security Groups and restrict ports properly.

Create an IAM role for EC2 with S3 and CloudWatch access.

The Ansible requirements belong to the next stage:

Install Docker, Docker Compose and Python.

Configure Fail2Ban or UFW.

Create a devops user.

Disable root SSH login.

Use Ansible Vault.

Store Jenkins credentials in SSM Parameter Store.

3. VPC and subnet design

We created:

VPC CIDR: 10.0.0.0/16
Public subnet:  10.0.1.0/24
Private subnet: 10.0.2.0/24
Availability Zone: ap-south-1a

Why?

The infrastructure is separated into public and private tiers.

The bastion needs to be reachable from the Internet, so it belongs in the public subnet.

The application server should not be directly reachable from the Internet, so it belongs in the private subnet.

Architecture:

Internet
   |
   v
Internet Gateway
   |
   v
Public Subnet
   |
   +---- Bastion EC2
   |
   +---- NAT Gateway
             |
             v
       Private Subnet
             |
             +---- Application EC2

4. Internet Gateway

We created an Internet Gateway attached to the VPC.

The public route table uses:

0.0.0.0/0 -> Internet Gateway

Why?

The bastion needs a public network path so an administrator can SSH to it.

The application server does not receive a public IP and therefore does not directly use this public Internet path.

5. NAT Gateway and Elastic IP

We created:

an Elastic IP

a NAT Gateway

The private route table uses:

0.0.0.0/0 -> NAT Gateway

Why?

The private application server may need outbound Internet access for:

operating-system packages

Docker installation

Python packages

software repositories

other outbound connections

But it should not have a public IP.

The intended flow is:

Private EC2
     |
     v
NAT Gateway
     |
     v
Internet

The Elastic IP provides the stable public address used by the NAT Gateway.

6. Route tables

Public route table

Associated with the public subnet:

0.0.0.0/0 -> IGW

Private route table

Associated with the private subnet:

0.0.0.0/0 -> NAT

Why two route tables?

The two subnet tiers have different network requirements:

Public subnet: direct Internet Gateway route.

Private subnet: outbound Internet through NAT.

This is the basis of the public/private network separation.

7. Security Groups

We created:

devops-lab-bastion-sg
devops-lab-app-sg

The Security Groups enforce access according to the role of each server.

Bastion Security Group

SSH is allowed only from the administrator's detected public IP:

103.203.45.163/32
TCP 22

Why /32?

A /32 represents one IPv4 address.

This is much more restrictive than:

0.0.0.0/0

so SSH is not exposed to every IPv4 address.

Application Security Group

The application SG allows:

TCP 80  from 10.0.0.0/16
TCP 443 from 10.0.0.0/16
TCP 22  from the bastion Security Group

Why?

The application server should not be directly accessible from the public Internet.

The intended administrative path is:

Administrator
     |
     v
Bastion
     |
     v
Application server

This is the bastion/jump-host pattern.

8. IAM role and instance profile

We created:

IAM role:
devops-lab-ec2-role

Instance profile:
devops-lab-ec2-profile

The role has:

AmazonS3ReadOnlyAccess
CloudWatchAgentServerPolicy

Why?

EC2 should use IAM roles instead of hardcoded AWS access keys.

The instance profile connects the IAM role to the EC2 instances:

IAM Role
   |
   v
Instance Profile
   |
   v
EC2

This gives the instances temporary AWS credentials automatically.

9. EC2 instances

We provisioned two Amazon Linux 2023 x86_64 EC2 instances.

Bastion

Subnet: 10.0.1.0/24
Public IP enabled: yes
Role: administrative jump host

Latest deployed values:

Instance ID: i-0a24fd41714317050
Private IP:  10.0.1.183
Public IP:   13.233.129.251

Application

Subnet: 10.0.2.0/24
Public IP enabled: no
Role: application server

Latest deployed values:

Instance ID: i-086120339d2309d62
Private IP: 10.0.2.137

The application instance has no public IP.

10. EC2 key pair

We verified the AWS key pair:

cloud-devops-lab-2026-key

It is supplied to both EC2 resources through:

key_name = "cloud-devops-lab-2026-key"

Why?

The key pair provides SSH authentication.

The bastion is the externally reachable administrative entry point, while the application server is intended to be reached through the bastion.

11. Terraform module structure

The project was organized as:

terraform/
├── main.tf
├── outputs.tf
└── modules/
    ├── vpc/
    ├── networking/
    ├── security/
    ├── iam/
    └── ec2/

Responsibilities:

Module

Responsibility

vpc

VPC and public/private subnets

networking

IGW, EIP, NAT, route tables and associations

security

Bastion and application Security Groups

iam

EC2 IAM role, policies and instance profile

ec2

Bastion and application EC2 instances

This keeps the infrastructure modular and easier to maintain.

12. Terraform workflow

We used:

terraform fmt -recursive
terraform init
terraform validate
terraform plan
terraform apply

Why?

terraform fmt

Formats the Terraform code consistently.

terraform init

Initializes the backend, modules and provider.

terraform validate

Checks the Terraform configuration for structural and syntax problems.

terraform plan

Shows what Terraform intends to create, change or destroy before anything is applied.

terraform apply

Actually creates or changes the AWS infrastructure.

13. Duplicate EC2 module problem

While adding the EC2 module, it was accidentally added twice.

Terraform reported:

Error: Duplicate module call

We inspected main.tf using:

nl -ba main.tf

and found two:

module "ec2"

blocks.

The duplicate was removed with:

sed -i '50,$d' main.tf

Then:

terraform fmt -recursive
terraform init
terraform validate
terraform plan

succeeded.

Lesson

Module names must be unique inside a Terraform root module.

14. AMI replacement lesson

The EC2 module selects the most recent Amazon Linux 2023 AMI:

most_recent = true

During the final apply, the selected AMI changed.

Terraform therefore planned:

2 to add
2 to destroy

because changing the AMI requires EC2 replacement.

The replacement completed successfully.

Important lesson

With:

most_recent = true

a future terraform plan can detect a newer AMI and propose replacing the instances.

For a production system, we should consider pinning a tested AMI or using a controlled image/version strategy.

15. Terraform state verification

After deployment we checked:

terraform state list | sort

The final state included the major resources for:

VPC
subnets
Internet Gateway
NAT Gateway
Elastic IP
route tables
route associations
Security Groups
IAM role
IAM policy attachments
instance profile
bastion EC2
application EC2

This confirms Terraform is managing the infrastructure.

16. Terraform outputs

Initially:

terraform output

reported:

Warning: No outputs found

We then created a root outputs.tf.

The outputs now expose:

bastion_instance_id
bastion_public_ip
bastion_private_ip
app_instance_id
app_private_ip
vpc_id

Latest values:

app_instance_id     = "i-086120339d2309d62"
app_private_ip      = "10.0.2.137"

bastion_instance_id = "i-0a24fd41714317050"
bastion_private_ip  = "10.0.1.183"
bastion_public_ip   = "13.233.129.251"

vpc_id              = "vpc-06270babfa410188d"

These outputs will be useful for the Ansible stage.

17. Final Phase 2 architecture

                         INTERNET
                            |
                            v
                    Internet Gateway
                            |
                            v
                 +----------------------+
                 |    PUBLIC SUBNET      |
                 |     10.0.1.0/24       |
                 |                      |
                 |   Bastion EC2         |
                 |   10.0.1.183          |
                 |   13.233.129.251      |
                 +----------+-----------+
                            |
                            | SSH
                            v
                 +----------------------+
                 |   PRIVATE SUBNET     |
                 |     10.0.2.0/24      |
                 |                      |
                 | Application EC2      |
                 | 10.0.2.137           |
                 | No public IP         |
                 +----------+-----------+
                            |
                            v
                      NAT Gateway
                            |
                            v
                         Internet

IAM:

EC2
 |
 v
devops-lab-ec2-profile
 |
 v
devops-lab-ec2-role
 |
 +---- S3 Read Only
 |
 +---- CloudWatch

18. Phase 2 completion checklist

Requirement

Status

VPC with CIDR

✅ Complete

Public subnet

✅ Complete

Private subnet

✅ Complete

Internet Gateway

✅ Complete

Elastic IP

✅ Complete

NAT Gateway

✅ Complete

Public route table

✅ Complete

Private route table

✅ Complete

Bastion Security Group

✅ Complete

Application Security Group

✅ Complete

IAM role

✅ Complete

S3 access

✅ Complete

CloudWatch access

✅ Complete

EC2 instance profile

✅ Complete

Bastion EC2

✅ Complete

Application EC2

✅ Complete

Terraform outputs

✅ Complete

Terraform state verification

✅ Complete

19. What remains for Phase 3

The following are not yet implemented:

Ansible
├── SSH/inventory
├── Docker
├── Docker Compose
├── Python
├── UFW or Fail2Ban
├── devops user
├── disable root SSH login
└── Ansible Vault

AWS automation
└── Jenkins credentials in SSM Parameter Store

These should be implemented after the Terraform infrastructure is verified.

20. Why Phase 3 comes after Phase 2

Terraform and Ansible have different responsibilities.

Terraform answers:

What infrastructure should exist?

Ansible answers:

How should the operating systems and software on that infrastructure be configured?

The workflow is therefore:

Terraform
    |
    v
AWS infrastructure
    |
    +---- Bastion
    |
    +---- Private application server
              |
              v
           Ansible
              |
              +---- Docker
              +---- Python
              +---- Firewall
              +---- devops user
              +---- SSH hardening
              +---- Vault/secrets

This separation makes the project easier to maintain and troubleshoot.

21. Current project position

PHASE 1
Foundation
    |
    v
PHASE 2
Terraform AWS Infrastructure
    |
    |  ✅ COMPLETE
    v
PHASE 3
Ansible + Security Hardening + Secrets
    |
    |  NEXT
    v
Application / Jenkins / CI-CD

The correct next step is therefore to preserve the working Terraform infrastructure and begin Phase 3 with secure SSH access through the bastion and an Ansible inventory.