variable "name" {
  description = "Nombre del release y del Service del agente."
  type        = string
  default     = "otel-node-agent"
}

variable "namespace" {
  description = "Namespace del agente (debe existir)."
  type        = string
}

variable "chart_version" {
  description = "Versión del chart open-telemetry/opentelemetry-collector."
  type        = string
  default     = "0.175.1"
}

variable "collector_image_tag" {
  description = "Tag de otel/opentelemetry-collector-contrib."
  type        = string
  default     = "0.162.0"
}

variable "gateway_loadbalancing_service" {
  description = "Service headless del Gateway en formato servicio.namespace (output loadbalancing_service de otel-gateway)."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+\\.[a-z0-9-]+$", var.gateway_loadbalancing_service))
    error_message = "gateway_loadbalancing_service debe tener el formato servicio.namespace."
  }
}

variable "memory_limit" {
  description = "Límite de memoria por pod del DaemonSet."
  type        = string
  default     = "256Mi"
}
