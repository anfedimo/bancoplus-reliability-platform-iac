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

variable "install_cert_manager" {
  description = "Instala cert-manager. false si el clúster lo provee como add-on de EKS."
  type        = bool
  default     = true
}
