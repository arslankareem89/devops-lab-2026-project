data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["137112412989"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
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

  tags = {
    Name        = "devops-lab-app"
    Environment = "dev"
    ManagedBy   = "Terraform"
    Role        = "application"
  }
}
