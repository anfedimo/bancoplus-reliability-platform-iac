# Contratos del rol de CI. Ejecutar: terraform test

mock_provider "aws" {
  # Los documentos de política simulados deben ser JSON válido para la validación de IAM
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
}

variables {
  github_repository   = "anfedimo/bancoplus-payments-qr"
  ecr_repository_arns = ["arn:aws:ecr:us-east-1:123456789012:repository/bancoplus/payments-qr"]
}

run "solo_main_publica" {
  command = plan

  assert {
    condition     = output.trusted_subjects == ["repo:anfedimo/bancoplus-payments-qr:ref:refs/heads/main"]
    error_message = "La confianza debe limitarse al repositorio y a la rama main."
  }
}

run "formato_con_ids_inmutables" {
  command = plan

  variables {
    github_ids = { owner_id = 38916299, repository_id = 1412377884 }
  }

  assert {
    condition     = output.trusted_subjects == ["repo:anfedimo@38916299/bancoplus-payments-qr@1412377884:ref:refs/heads/main"]
    error_message = "Con github_ids, el subject debe usar el formato owner@id/repo@id que emite GitHub."
  }
}

run "rechaza_repositorio_mal_formado" {
  command = plan

  variables {
    github_repository = "bancoplus-payments-qr"
  }

  expect_failures = [var.github_repository]
}

run "rechaza_sin_repositorios_ecr" {
  command = plan

  variables {
    ecr_repository_arns = []
  }

  expect_failures = [var.ecr_repository_arns]
}
