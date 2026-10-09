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

variable "admin_cidrs" {
  description = "CIDRs autorizados para la API de EKS y para Grafana."
  type        = list(string)

  validation {
    condition     = length(var.admin_cidrs) > 0 && alltrue([for c in var.admin_cidrs : can(cidrhost(c, 0)) && c != "0.0.0.0/0"])
    error_message = "admin_cidrs debe contener CIDRs válidos y no puede abrirse a 0.0.0.0/0."
  }
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
