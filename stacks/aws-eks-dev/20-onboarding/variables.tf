variable "aws_account_id" {
  description = "Cuenta AWS de destino. El provider rechaza cualquier otra cuenta."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "aws_account_id debe tener 12 dígitos."
  }
}

variable "region" {
  description = "Región AWS del clúster EKS."
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Nombre del clúster EKS (gestionado por otro stack)."
  type        = string
}

variable "amp_workspace_id" {
  description = "Workspace de Amazon Managed Prometheus donde se publican las reglas SLO."
  type        = string
}

variable "ecr_registry" {
  description = "Registro ECR de las imágenes de las verticales (<ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com)."
  type        = string
}
