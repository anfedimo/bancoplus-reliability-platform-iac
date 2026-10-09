# Variables de la capa ci-identity (identidad de CI para los repositorios de aplicación).
variable "aws_profile" {
  description = "Perfil de AWS CLI de la cuenta de la PoC."
  type        = string
}

variable "aws_account_id" {
  description = "Cuenta AWS de destino. El provider rechaza cualquier otra cuenta."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "aws_account_id debe tener 12 dígitos."
  }
}

variable "region" {
  description = "Región AWS."
  type        = string
  default     = "us-east-1"
}

variable "github_ids" {
  description = "IDs inmutables de GitHub (API: /repos/<owner>/<repo> → owner.id, id)."
  type = object({
    owner_id      = number
    repository_id = number
  })
  default = { owner_id = 38916299, repository_id = 1412377884 }
}

variable "github_repository" {
  description = "Repositorio de la aplicación autorizado a publicar en ECR."
  type        = string
  default     = "anfedimo/bancoplus-payments-qr"
}

locals {
  # Guardrail FinOps: toda pieza creada por Terraform lleva el TTL del entorno
  ephemeral_tags = {
    Environment = "ephemeral-poc"
    Owner       = "plataforma-confiabilidad"
    Purpose     = "evaluacion-tecnica"
    TTL         = "72h"
  }
}
