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

variable "budget_alert_email" {
  description = "Correo de las alertas de AWS Budgets."
  type        = string
  default     = ""
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

# --- Específicas de la capa cluster ---

variable "kubernetes_version" {
  description = "Versión de Kubernetes de EKS. Verificar disponibilidad: aws eks describe-cluster-versions."
  type        = string
  default     = "1.35"
}

variable "node_instance_types" {
  description = "Tipos de instancia del node group. ARM (Graviton): las imágenes se compilan nativas en Apple Silicon. Varios tipos mejoran la disponibilidad Spot."
  type        = list(string)
  default     = ["t4g.xlarge", "m7g.xlarge", "m6g.xlarge"]
}

variable "node_capacity_type" {
  description = "SPOT (≈70% más barato, interrumpible) u ON_DEMAND."
  type        = string
  default     = "SPOT"

  validation {
    condition     = contains(["SPOT", "ON_DEMAND"], var.node_capacity_type)
    error_message = "node_capacity_type debe ser SPOT u ON_DEMAND."
  }
}

variable "node_count" {
  description = "Nodos del node group (Operator HA, Gateway ×2, kube-prometheus-stack, Tempo y la vertical de Pagos)."
  type        = number
  default     = 2
}

variable "budget_limit_usd" {
  description = "Tope de AWS Budgets para el entorno efímero."
  type        = number
  default     = 30
}
