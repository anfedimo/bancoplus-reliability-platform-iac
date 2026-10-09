# State local para la PoC. En stacks/aws-eks-*: backend "s3" con use_lockfile = true (locking nativo).
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
