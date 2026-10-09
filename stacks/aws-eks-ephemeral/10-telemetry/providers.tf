# Providers comunes a las capas de plataforma del entorno efímero (idénticos en 00, 10 y 20).
provider "aws" {
  profile             = var.aws_profile
  region              = var.region
  allowed_account_ids = [var.aws_account_id]

  default_tags {
    tags = local.ephemeral_tags
  }
}

data "aws_eks_cluster" "this" {
  name = var.cluster_name
}

locals {
  # Token de corta duración por invocación: sin credenciales del clúster en archivos
  eks_exec = {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", var.region, "--profile", var.aws_profile]
  }
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)

  exec {
    api_version = local.eks_exec.api_version
    command     = local.eks_exec.command
    args        = local.eks_exec.args
  }
}

provider "helm" {
  kubernetes = {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    exec                   = local.eks_exec
  }
}
