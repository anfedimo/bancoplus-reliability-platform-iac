# Capa ci-identity · Rol OIDC de GitHub Actions para publicar en ECR. State propio: no modifica la
# capa cluster. Destruir antes que la capa cluster (lee el repositorio ECR que ella crea).

data "aws_ecr_repository" "payments" {
  name = "bancoplus/payments-qr"
}

module "payments_ci" {
  source = "../../../modules/github-ci-ecr-role"

  github_repository   = var.github_repository
  github_ids          = var.github_ids
  ecr_repository_arns = [data.aws_ecr_repository.payments.arn]
}
