output "role_arn" {
  description = "ARN del rol que asume GitHub Actions (variable AWS_ROLE_ARN del repositorio)."
  value       = aws_iam_role.ci.arn
}

output "oidc_provider_arn" {
  description = "ARN del proveedor OIDC de GitHub."
  value       = local.provider_arn
}

output "trusted_subjects" {
  description = "Subjects OIDC autorizados a asumir el rol."
  value       = local.trusted_subjects
}
