# Provider AWS común a todas las capas del entorno efímero (idéntico en todas las capas).
provider "aws" {
  profile             = var.aws_profile
  region              = var.region
  allowed_account_ids = [var.aws_account_id]

  default_tags {
    tags = local.ephemeral_tags
  }
}
