# bucket y region vía -backend-config=../backend.hcl (configuración parcial)
terraform {
  backend "s3" {
    key          = "reliability-platform/aws-eks-dev/20-onboarding.tfstate"
    use_lockfile = true
    encrypt      = true
  }
}
