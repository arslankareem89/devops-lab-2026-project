Phase 3 Operations Record

What problem we had

The AWS infrastructure was running, but the main problem at the start of this phase was SSH access.

The EC2 instances were created with the AWS key pair:

cloud-devops-lab-2026-key

The private .pem file was not available in the WSL project or WSL home directory. Searches only found unrelated Flutter test certificates.

We decided not to destroy or recreate the EC2 instances just to solve the missing key problem.

1. Checked the existing infrastructure

The running instances were:

Bastion: i-0e4ee80beca7715e3

Bastion private IP: 10.0.1.103

App: i-0c5818d64bbb4d1a8

App private IP: 10.0.2.126

VPC: vpc-06270babfa410188d

The app did not have a public IP.

The existing AWS key pair remained cloud-devops-lab-2026-key.

2. Created a local SSH key

A usable ED25519 key already existed in WSL:

~/.ssh/devops-lab-2026-ssh
~/.ssh/devops-lab-2026-ssh.pub

The public key was installed on the EC2 instances instead of trying to recover the old .pem.

3. First Terraform plan showed an unexpected EC2 replacement

After adding the SSH bootstrap, Terraform wanted to do:

Plan: 2 to add, 0 to change, 2 to destroy.

The reason was the AMI lookup:

most_recent = true

Terraform was selecting a newer Amazon Linux AMI than the one already running.

The running instances were checked with AWS CLI and both used:

ami-035827357e3c7e810

The AMI lookup was changed to use that exact image.

The next plan showed:

Plan: 0 to add, 1 to change, 0 to destroy.

Only the bastion user-data change remained.

4. Added the local public key with Terraform

The root Terraform module passes the local public key:

ssh_public_key = file(pathexpand("~/.ssh/devops-lab-2026-ssh.pub"))

The bastion user_data added the key to:

/home/ec2-user/.ssh/authorized_keys

Terraform was applied with:

0 added
1 changed
0 destroyed

SSH to the bastion then worked.

5. Added SSM access

The EC2 IAM role was given:

AmazonSSMManagedInstanceCore

After this, AWS Systems Manager showed both EC2 instances as Online.

This gave us another way to manage the servers and also allowed us to recover the app access without rebuilding it.

6. Fixed the private app access

The app was already running when its Terraform user_data was added. Updating the Terraform field did not make the new bootstrap script run as a first-boot script on the existing instance.

SSH to the app first failed with:

Permission denied (publickey...)

We used AWS Systems Manager Run Command to put the same local public key into:

/home/ec2-user/.ssh/authorized_keys

The SSM command completed with:

Status: Success

After that:

ssh devops-app

worked through the bastion.

7. SSH aliases and ProxyJump

The working SSH path became:

Laptop
  |
  | SSH key
  v
Bastion
  |
  | ProxyJump
  v
Private App

A local SSH config was used for the bastion and private app.

The private app remained without a public IP.

8. Public IP changed and SSH stopped working

The laptop public IP changed from:

103.203.45.155

to:

103.203.45.159

The bastion Security Group still allowed the old address:

103.203.45.155/32

SSH started timing out.

The current public IP was checked with:

curl -4 https://checkip.amazonaws.com

The Security Group was checked with AWS CLI.

9. Made the bastion SSH CIDR dynamic

Instead of opening port 22 to the whole Internet, Terraform now gets the current public IP with:

data "http" "my_public_ip" {
  url = "https://checkip.amazonaws.com"
}

The security module receives:

admin_cidr_blocks = ["${trimspace(data.http.my_public_ip.response_body)}/32"]

The next plan changed only:

103.203.45.155/32

to:

103.203.45.159/32

and showed:

Plan: 0 to add, 1 to change, 0 to destroy.

SSH worked again.

10. Ansible inventory problem

The first Ansible inventory used the same names for groups and hosts, which produced warnings:

Found both group and host with same name: bastion
Found both group and host with same name: app

The inventory was changed to:

[bastions]
bastion-01

[apps]
app-01

The app used the bastion as its ProxyJump.

After the change:

ansible all -m ping

returned SUCCESS for both hosts.

11. Baseline check

Ansible was used to check the existing software.

Both hosts already had:

Python 3.9.25

Docker and Docker Compose were not installed.

12. Installed Docker and Docker Compose

Ansible installed:

Docker 25.0.14
Docker Compose v2.39.2

on both the bastion and app.

The playbook completed successfully on both hosts.

13. Created the devops user

Ansible created devops on both instances.

The user was added to the wheel group and the SSH key was installed.

Checks showed:

devops
devops wheel

and:

sudo -n whoami

returned:

root

SSH as devops worked on the bastion and private app.

14. Disabled root SSH login

After confirming devops access worked, Ansible changed:

PermitRootLogin no

and restarted sshd.

The effective configuration was checked with:

ansible all -b -m shell -a "sshd -T | grep '^permitrootlogin '"

Both hosts returned:

permitrootlogin no

Ansible access as devops continued to work.

15. Chose Fail2Ban instead of UFW

The assignment allows either UFW or Fail2Ban.

UFW was checked first, but the Amazon Linux 2023 repositories did not have a ufw package.

Fail2Ban was available in the Amazon Linux repository, so Fail2Ban was selected.

16. Installed and configured Fail2Ban

Ansible installed Fail2Ban and created an SSH jail.

The jail used:

maxretry = 5
findtime = 10m
bantime = 10m

Both servers showed:

Jail list: sshd

and:

Currently banned: 0

No deliberate failed-login test was performed so that the current laptop IP was not accidentally banned.

17. Created Ansible Vault

A local Vault password file was created:

ansible/.vault_pass

and added to .gitignore.

The encrypted variables file was created:

ansible/group_vars/all/vault.yml

The Vault file was encrypted and set to local permission 600.

The plaintext Vault password was not committed.

18. Stored Jenkins credentials in SSM Parameter Store

The SSM Parameter Store was checked and was initially empty.

Two Jenkins-related parameters were created:

/Jenkins/dockerhub/username
/Jenkins/dockerhub/password

The username type is:

String

The password type is:

SecureString

The password value was not placed in Git, Terraform, or Ansible source.

19. Git checkpoints

Phase 2 was already committed and pushed as:

d768b43 Phase 2: Provision AWS infrastructure with Terraform

The secure EC2 access work was committed and pushed as:

05c3040 Phase 3: Establish secure EC2 access

The Ansible configuration work was committed and pushed as:

7b3a667 Phase 3: Configure EC2 servers with Ansible

20. Final Phase 3 state

The working access path is:

Laptop
  |
  | SSH with devops-lab-2026-ssh
  v
Bastion
  |
  | ProxyJump
  v
Private App

Both instances are also registered with SSM.

The following Phase 3 items were implemented and verified:

Security Groups

EC2 IAM role

SSM access

Ansible inventory and connectivity

Python

Docker

Docker Compose

devops user

sudo access

root SSH disabled

Fail2Ban

Ansible Vault

Jenkins credentials in SSM Parameter Store