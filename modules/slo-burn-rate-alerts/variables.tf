variable "slo_file" {
  description = "Ruta del SLO como código (slo/*.yaml). Fuente única de objetivos, selector y ventanas."
  type        = string

  validation {
    condition     = fileexists(var.slo_file)
    error_message = "slo_file no existe."
  }
}

variable "profile" {
  description = "Perfil de ventanas del SLO: prod (30d · 1h/5m · 6h/30m) o poc (ventanas comprimidas)."
  type        = string
  default     = "prod"

  validation {
    condition     = contains(["prod", "poc"], var.profile)
    error_message = "profile debe ser prod o poc."
  }
}

variable "namespace" {
  description = "Namespace de la vertical dueña del SLO (PrometheusRule y dashboard)."
  type        = string
}

variable "runbook_url" {
  description = "Runbook enlazado en las alertas."
  type        = string
  default     = "https://github.com/anfedimo/sre-finops-otel-collector#runbook-error-budget"
}

variable "metrics" {
  description = "Nombres de las métricas RED de span_metrics en Prometheus."
  type = object({
    calls     = optional(string, "traces_span_metrics_calls_total")
    histogram = optional(string, "traces_span_metrics_duration_milliseconds")
  })
  default = {}
}

variable "dashboard_enabled" {
  description = "Publica el dashboard de Error Budget (ConfigMap descubierto por el sidecar de Grafana)."
  type        = bool
  default     = true
}
