data "aws_ami" "amazon_linux" {
  most_recent = false
  owners      = ["137112412989"]

  filter {
    name   = "image-id"
    values = ["ami-035827357e3c7e810"]
  }
}

data "aws_ami" "amazon_linux_2023" {
  most_recent = false
  owners      = ["137112412989"]

  filter {
    name   = "image-id"
    values = ["ami-0ac7b260cf76d8865"]
  }
}

resource "aws_instance" "bastion" {

  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = [var.bastion_security_group_id]
  associate_public_ip_address = true
  key_name                    = var.key_name
  iam_instance_profile        = var.instance_profile_name

    user_data = <<-EOF
    #!/bin/bash
    mkdir -p /home/ec2-user/.ssh
    echo '${var.ssh_public_key}' >> /home/ec2-user/.ssh/authorized_keys
    chown -R ec2-user:ec2-user /home/ec2-user/.ssh
    chmod 700 /home/ec2-user/.ssh
    chmod 600 /home/ec2-user/.ssh/authorized_keys
  EOF

  tags = {
    Name        = "devops-lab-bastion"
    Environment = "dev"
    ManagedBy   = "Terraform"
    Role        = "bastion"
  }
}

resource "aws_instance" "app" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  subnet_id                   = var.private_subnet_id
  vpc_security_group_ids      = [var.app_security_group_id]
  associate_public_ip_address = false
  key_name                    = var.key_name
  iam_instance_profile        = var.instance_profile_name
    user_data = <<-EOF
    #!/bin/bash
    mkdir -p /home/ec2-user/.ssh
    echo '${var.ssh_public_key}' >> /home/ec2-user/.ssh/authorized_keys
    chown -R ec2-user:ec2-user /home/ec2-user/.ssh
    chmod 700 /home/ec2-user/.ssh
    chmod 600 /home/ec2-user/.ssh/authorized_keys
  EOF

  tags = {
    Name        = "devops-lab-app"
    Environment = "dev"
    ManagedBy   = "Terraform"
    Role        = "application"
  }
}

resource "aws_instance" "ci" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = var.ci_instance_type
  subnet_id                   = var.private_subnet_id
  vpc_security_group_ids      = [var.app_security_group_id]
  associate_public_ip_address = false
  key_name                    = var.key_name
  iam_instance_profile        = var.instance_profile_name
  user_data = <<-EOF
    #!/bin/bash
    mkdir -p /home/ec2-user/.ssh
    echo '${var.ssh_public_key}' >> /home/ec2-user/.ssh/authorized_keys
    chown -R ec2-user:ec2-user /home/ec2-user/.ssh
    chmod 700 /home/ec2-user/.ssh
    chmod 600 /home/ec2-user/.ssh/authorized_keys
  EOF

  tags = {
    Name        = "devops-lab-ci"
    Environment = "dev"
    ManagedBy   = "Terraform"
    Role        = "ci"
  }
}

