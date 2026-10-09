# github-ci-ecr-role

Rol IAM para GitHub Actions con federación OIDC: el pipeline obtiene credenciales temporales por
ejecución, sin llaves de acceso almacenadas como secretos.

```hcl
module "payments_ci" {
  source              = "../../modules/github-ci-ecr-role"
  github_repository   = "anfedimo/bancoplus-payments-qr"
  ecr_repository_arns = [data.aws_ecr_repository.payments.arn]
}
```

| Control | Implementación |
|---|---|
| Sin credenciales estáticas | `sts:AssumeRoleWithWebIdentity` con el token OIDC de GitHub |
| Alcance del origen | `sub` = `repo:<owner>@<id>/<repo>@<id>:ref:refs/heads/main` (IDs inmutables con `github_ids`): forks y PR no publican; un repositorio recreado con el mismo nombre no hereda el acceso |
| Mínimo privilegio | Solo acciones de push sobre los repositorios ECR indicados |
| Sesión corta | `max_session_duration` 1 h |
