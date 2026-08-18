terraform {
  backend "s3" {
    bucket       = "devops-lab-2026-terraform-state-arslan"
    key          = "devops-lab/terraform.tfstate"
    region       = "ap-south-1"
    use_lockfile = true
    encrypt      = true
  }
}
