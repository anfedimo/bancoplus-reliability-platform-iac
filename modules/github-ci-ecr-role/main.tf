# Rol de CI para GitHub Actions vía OIDC: sin llaves de acceso de larga duración.
# Cada ejecución obtiene credenciales temporales (máx. 1 h) limitadas a publicar en ECR.

locals {
  provider_url = "token.actions.githubusercontent.com"
  role_name    = var.role_name != "" ? var.role_name : "gha-${replace(var.github_repository, "/", "-")}-ecr-push"
  # Únicos "sub" de token OIDC aceptados: repositorio y ramas autorizadas. Con github_ids se usa el
  # formato con IDs inmutables (repo:owner@id/repo@id:ref:...), resistente a repo-jacking.
  repo_parts = split("/", var.github_repository)
  subject_repo = var.github_ids == null ? var.github_repository : format(
    "%s@%d/%s@%d", local.repo_parts[0], var.github_ids.owner_id, local.repo_parts[1], var.github_ids.repository_id
  )
  trusted_subjects = [for ref in var.allowed_refs : "repo:${local.subject_repo}:ref:${ref}"]
  provider_arn     = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn
}

resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 1 : 0

  url            = "https://${local.provider_url}"
  client_id_list = ["sts.amazonaws.com"]
}

data "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 0 : 1
  url   = "https://${local.provider_url}"
}

data "aws_iam_policy_document" "trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Solo el repositorio y las ramas autorizadas: un fork o un PR no pueden asumir el rol
    condition {
      test     = "StringEquals"
      variable = "${local.provider_url}:sub"
      values   = local.trusted_subjects
    }
  }
}

resource "aws_iam_role" "ci" {
  name                 = local.role_name
  assume_role_policy   = data.aws_iam_policy_document.trust.json
  max_session_duration = var.max_session_duration
}

data "aws_iam_policy_document" "ecr_push" {
  # GetAuthorizationToken no admite restricción por recurso
  statement {
    sid       = "EcrLogin"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "EcrPushScopedRepositories"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = var.ecr_repository_arns
  }
}

resource "aws_iam_role_policy" "ecr_push" {
  name   = "ecr-push"
  role   = aws_iam_role.ci.id
  policy = data.aws_iam_policy_document.ecr_push.json
}
