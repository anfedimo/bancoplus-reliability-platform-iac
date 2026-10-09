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
