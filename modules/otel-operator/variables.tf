variable "install_cert_manager" {
  description = "Instala cert-manager (requerido por los webhooks del Operator). false si el clúster ya lo provee."
  type        = bool
  default     = true
}

variable "cert_manager_namespace" {
  description = "Namespace de cert-manager."
  type        = string
  default     = "cert-manager"
}

variable "cert_manager_chart_version" {
  description = "Versión del chart jetstack/cert-manager."
  type        = string
  default     = "v1.21.2"
}

variable "operator_namespace" {
  description = "Namespace del OpenTelemetry Operator."
  type        = string
  default     = "opentelemetry-operator-system"
}

variable "operator_chart_version" {
  description = "Versión del chart open-telemetry/opentelemetry-operator."
  type        = string
  default     = "0.124.1"
}

variable "collector_image" {
  description = "Imagen por defecto de los OpenTelemetryCollector gestionados por el Operator."
  type = object({
    repository = optional(string, "otel/opentelemetry-collector-contrib")
    tag        = optional(string, "0.162.0")
  })
  default = {}
}

variable "java_agent_image" {
  description = "Imagen del agente Java inyectado. Fijada para que una actualización del Operator no cambie el agente en producción."
  type = object({
    repository = optional(string, "ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-java")
    tag        = optional(string, "2.32.0")
  })
  default = {}
}
