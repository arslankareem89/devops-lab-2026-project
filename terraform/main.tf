data "http" "my_public_ip" {
  url = "https://checkip.amazonaws.com"
}

module "vpc" {
  source = "./modules/vpc"

  vpc_name            = "devops-lab-vpc"
  environment         = "dev"
  vpc_cidr            = "10.0.0.0/16"
  public_subnet_cidr  = "10.0.1.0/24"
  private_subnet_cidr = "10.0.2.0/24"
  availability_zone   = "ap-south-1a"
}
module "networking" {
  source = "./modules/networking"

  name              = "devops-lab"
  environment       = "dev"
  vpc_id            = module.vpc.vpc_id
  public_subnet_id  = module.vpc.public_subnet_id
  private_subnet_id = module.vpc.private_subnet_id
}
module "security" {
  source = "./modules/security"

  name              = "devops-lab"
  environment       = "dev"
  vpc_id            = module.vpc.vpc_id
  vpc_cidr          = module.vpc.vpc_cidr
  admin_cidr_blocks = ["${trimspace(data.http.my_public_ip.response_body)}/32"]
}

module "iam" {
  source = "./modules/iam"

  name        = "devops-lab"
  environment = "dev"
}

module "ec2" {
  source = "./modules/ec2"

  vpc_id                    = module.vpc.vpc_id
  public_subnet_id          = module.vpc.public_subnet_id
  private_subnet_id         = module.vpc.private_subnet_id
  bastion_security_group_id = module.security.bastion_security_group_id
  app_security_group_id     = module.security.app_security_group_id
  instance_profile_name     = module.iam.instance_profile_name
   instance_type             = "t3.micro"
   ci_instance_type          = "c7i-flex.large"
  key_name                  = "cloud-devops-lab-2026-key"
  ssh_public_key            = file(pathexpand("~/.ssh/devops-lab-2026-ssh.pub"))
}



