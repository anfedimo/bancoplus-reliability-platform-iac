variable "namespace" {
  description = "Namespace de Argo CD."
  type        = string
  default     = "argocd"
}

variable "argocd_chart_version" {
  description = "Versión del chart argo/argo-cd."
  type        = string
  default     = "10.10.2"
}

variable "argocd_apps_chart_version" {
  description = "Versión del chart argo/argocd-apps (aplicación raíz)."
  type        = string
  default     = "2.0.6"
}

variable "gitops_repo_url" {
  description = "Repositorio GitOps con el estado deseado del clúster."
  type        = string

  validation {
    condition     = can(regex("^https://", var.gitops_repo_url))
    error_message = "gitops_repo_url debe ser una URL https."
  }
}

variable "target_revision" {
  description = "Rama o tag del repositorio GitOps que reconcilia el clúster."
  type        = string
  default     = "main"
}

variable "server_service" {
  description = "Exposición de la UI de Argo CD. LoadBalancer + source_ranges la publica con allowlist (entornos cloud)."
  type = object({
    type          = optional(string, "ClusterIP")
    annotations   = optional(map(string), {})
    source_ranges = optional(list(string), [])
  })
  default = {}

  validation {
    condition     = !contains(var.server_service.source_ranges, "0.0.0.0/0")
    error_message = "Argo CD no puede exponerse a 0.0.0.0/0: usar una allowlist."
  }

  validation {
    condition     = var.server_service.type != "LoadBalancer" || length(var.server_service.source_ranges) > 0
    error_message = "Un LoadBalancer de Argo CD requiere source_ranges (allowlist)."
  }
}

variable "root_path" {
  description = "Overlay de aplicaciones del entorno (p. ej. bootstrap/applications/overlays/eks-ephemeral)."
  type        = string
}
