output "payments_ci_role_arn" {
  description = "Rol para la variable AWS_ROLE_ARN del repositorio bancoplus-payments-qr."
  value       = module.payments_ci.role_arn
}

output "ecr_repository_url" {
  description = "Repositorio ECR de la aplicación (variable ECR_REPOSITORY del pipeline)."
  value       = data.aws_ecr_repository.payments.repository_url
}
