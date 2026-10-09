variable "github_repository" {
  description = "Repositorio de GitHub (owner/nombre) autorizado a asumir el rol."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "github_repository debe tener el formato owner/nombre."
  }
}

variable "github_ids" {
  description = "IDs inmutables del owner y del repositorio. GitHub los incluye en el claim sub del token OIDC (owner@id/repo@id): un repositorio borrado y recreado con el mismo nombre no hereda el acceso."
  type = object({
    owner_id      = number
    repository_id = number
  })
  default = null
}

variable "allowed_refs" {
  description = "Refs de git que pueden publicar imágenes. Por defecto solo main: los PR construyen y escanean sin publicar."
  type        = list(string)
  default     = ["refs/heads/main"]
}

variable "ecr_repository_arns" {
  description = "Repositorios ECR en los que el rol puede publicar imágenes."
  type        = list(string)

  validation {
    condition     = length(var.ecr_repository_arns) > 0 && alltrue([for a in var.ecr_repository_arns : can(regex("^arn:aws:ecr:", a))])
    error_message = "ecr_repository_arns debe contener al menos un ARN de ECR."
  }
}

variable "create_oidc_provider" {
  description = "Crea el proveedor OIDC de GitHub (uno por cuenta). false si ya existe."
  type        = bool
  default     = true
}

variable "role_name" {
  description = "Nombre del rol IAM. Por defecto deriva del repositorio."
  type        = string
  default     = ""
}

variable "max_session_duration" {
  description = "Duración máxima de la sesión (segundos). Un build no necesita más de 1 h."
  type        = number
  default     = 3600
}
