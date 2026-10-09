variable "kubeconfig_path" {
  description = "Ruta del kubeconfig."
  type        = string
  default     = "~/.kube/config"
}

variable "kube_context" {
  description = "Contexto de kubeconfig. Restringido a perfiles de minikube para impedir un apply accidental sobre EKS."
  type        = string
  default     = "bancoplus"

  validation {
    condition     = can(regex("^(minikube|bancoplus)", var.kube_context))
    error_message = "El stack local-minikube solo puede aplicarse sobre contextos de minikube."
  }
}

variable "namespace" {
  description = "Namespace de la capa de telemetría."
  type        = string
  default     = "observability"
}

variable "gateway_replicas" {
  description = "Réplicas del Gateway. 2 para demostrar tail sampling consistente vía loadbalancing."
  type        = number
  default     = 2
}

variable "legacy_apm_enabled" {
  description = "Dual-Shipping hacia el APM legado. false = cutover (F3)."
  type        = bool
  default     = true
}
