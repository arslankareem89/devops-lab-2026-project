Phase 3 Decision Log

1. Keep the existing AWS key pair

Problem

The EC2 instances used:

cloud-devops-lab-2026-key

but the original private .pem was not available in the current WSL environment.

Decision

Do not replace or rename the AWS key pair.

Use the local ED25519 key:

~/.ssh/devops-lab-2026-ssh

and install its public key on the instances.

Why

The infrastructure was already running. Replacing the AWS key would have introduced a bigger infrastructure change just to solve a local SSH problem.

Result

SSH access was restored without recreating the EC2 instances.

2. Pin the AMI after Terraform wanted to replace both servers

Problem

Terraform initially selected a newer AMI because the configuration used:

most_recent = true

The plan wanted:

2 to add
0 to change
2 to destroy

Decision

Use the AMI already running on the instances:

ami-035827357e3c7e810

Why

The task was to add SSH access, not replace the working servers.

Result

The plan changed to:

0 to add
1 to change
0 to destroy

and the bastion was updated in place.

3. Use SSM as another way to manage the servers

Problem

The original .pem was unavailable.

Decision

Attach:

AmazonSSMManagedInstanceCore

to the EC2 role.

Why

SSM gives us another management path that does not depend on the original private key.

Result

Both instances became Online in Systems Manager.

4. Use SSM Run Command for the already-running app

Problem

The app had already booted before the SSH user_data change was made.

Decision

Use SSM Run Command to add the local public key directly to the app's authorized_keys.

Why

It avoided destroying and recreating the app.

Result

The SSM command succeeded and ssh devops-app worked.

5. Keep the app private and use the bastion

Decision

Use:

Laptop -> Bastion -> Private App

with SSH ProxyJump.

Why

The app has no public IP and the architecture is based on a public bastion plus private application server.

Result

SSH access through the bastion worked manually and then through Ansible.

6. Make the bastion SSH CIDR dynamic

Problem

The laptop public IP changed from:

103.203.45.155

to:

103.203.45.159

The old /32 Security Group rule caused SSH timeouts.

Decision

Use Terraform's HTTP provider to get the current public IP and apply /32.

Why

We wanted to keep SSH restricted rather than using:

0.0.0.0/0

Result

Terraform updated only the bastion SSH rule and SSH worked again.

7. Use distinct Ansible group and host names

Problem

The first inventory used the same names for groups and hosts:

bastion
app

Ansible warned about duplicate group/host names.

Decision

Use:

bastions
  bastion-01

apps
  app-01

Why

It removes ambiguity and makes the inventory easier to understand.

Result

The inventory loaded without those warnings and Ansible ping worked.

8. Use the devops user before disabling root SSH

Problem

The assignment requires both a new administrative user and disabled root SSH login.

Decision

Create devops, install its SSH key, give it sudo, verify it, and only then disable root SSH.

Why

This avoids locking ourselves out during hardening.

Result

devops login and sudo worked on both servers before root SSH was disabled.

9. Disable root SSH login

Decision

Set:

PermitRootLogin no

Why

This is explicitly required by the Phase 3 project requirements.

Result

The effective configuration showed:

permitrootlogin no

on both servers, while devops access continued to work.

10. Use Fail2Ban instead of UFW

Problem

UFW was not available from the configured Amazon Linux 2023 repository.

Decision

Use Fail2Ban.

Why

The assignment allows either UFW or Fail2Ban, and Fail2Ban was available on the current OS.

Result

An SSH jail was enabled on both instances.

11. Use Ansible Vault for Ansible-side secrets

Decision

Keep Ansible secrets in:

ansible/group_vars/all/vault.yml

and keep the local Vault password in:

ansible/.vault_pass

Why

The secret value should not be stored as plaintext in Git.

Result

The Vault file is encrypted and the password file is ignored by Git.

12. Use SSM Parameter Store for Jenkins credentials

Decision

Create:

/Jenkins/dockerhub/username
/Jenkins/dockerhub/password

The password is a SecureString.

Why

The assignment explicitly says Jenkins credentials should not be hardcoded.

Result

Both parameters exist in SSM Parameter Store, with the password stored as SecureString.

13. Keep the Phase 3 work in Git checkpoints

Phase 2 was already committed:

d768b43 Phase 2: Provision AWS infrastructure with Terraform

Phase 3 access was committed:

05c3040 Phase 3: Establish secure EC2 access

The Ansible work was committed:

7b3a667 Phase 3: Configure EC2 servers with Ansible

This keeps the project history readable and makes it easier to identify where the SSH/access work and the Ansible work were introduced.

Phase 3 result

The final Phase 3 result is a working Terraform + Ansible setup with:

AWS Security Groups
IAM role
SSM
SSH through bastion
Private application server
Ansible
Docker
Docker Compose
devops user
Root SSH disabled
Fail2Ban
Ansible Vault
Jenkins credentials in SSM

The next phase starts from this working state.