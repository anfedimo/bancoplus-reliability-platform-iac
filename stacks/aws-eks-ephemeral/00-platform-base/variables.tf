# Variables comunes a todas las capas del entorno efímero (idénticas en todas las capas).
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

variable "cluster_name" {
  description = "Nombre del clúster EKS efímero."
  type        = string
  default     = "bancoplus-poc"
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
