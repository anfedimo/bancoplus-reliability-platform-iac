variable "namespace" {
  description = "Namespace de los backends (debe existir)."
  type        = string
}

variable "kube_prometheus_stack_chart_version" {
  description = "Versión del chart prometheus-community/kube-prometheus-stack."
  type        = string
  default     = "92.2.0"
}

variable "tempo_chart_version" {
  description = "Versión del chart grafana/tempo (single binary)."
  type        = string
  default     = "1.24.4"
}

variable "legacy_apm_standin_image" {
  description = "Imagen del stand-in del APM legado (recibe OTLP/HTTP como lo hace Dynatrace)."
  type        = string
  default     = "jaegertracing/jaeger:2.22.0"
}

variable "grafana_admin_password" {
  description = "Contraseña del usuario admin de Grafana."
  type        = string
  sensitive   = true
}

variable "cluster_monitoring_enabled" {
  description = "Reglas y scrapes del mixin de Kubernetes (API server, kubelet, CoreDNS). Fuera del alcance de la plataforma de telemetría; en EKS lo cubre el monitoreo del clúster."
  type        = bool
  default     = false
}

variable "grafana_service" {
  description = "Exposición de Grafana. LoadBalancer + source_ranges publica Grafana con allowlist (entornos cloud)."
  type = object({
    type          = optional(string, "ClusterIP")
    annotations   = optional(map(string), {})
    source_ranges = optional(list(string), [])
  })
  default = {}

  validation {
    condition     = !contains(var.grafana_service.source_ranges, "0.0.0.0/0")
    error_message = "Grafana no puede exponerse a 0.0.0.0/0: usar una allowlist."
  }

  validation {
    condition     = var.grafana_service.type != "LoadBalancer" || length(var.grafana_service.source_ranges) > 0
    error_message = "Un LoadBalancer de Grafana requiere source_ranges (allowlist)."
  }
}

variable "legacy_apm_service" {
  description = "Exposición de la UI del stand-in del APM legado (consola propia, como Dynatrace). Mismas reglas que Grafana."
  type = object({
    type          = optional(string, "ClusterIP")
    annotations   = optional(map(string), {})
    source_ranges = optional(list(string), [])
  })
  default = {}

  validation {
    condition     = !contains(var.legacy_apm_service.source_ranges, "0.0.0.0/0")
    error_message = "El APM legado no puede exponerse a 0.0.0.0/0: usar una allowlist."
  }

  validation {
    condition     = var.legacy_apm_service.type != "LoadBalancer" || length(var.legacy_apm_service.source_ranges) > 0
    error_message = "Un LoadBalancer del APM legado requiere source_ranges (allowlist)."
  }
}

variable "persistence" {
  description = "Volúmenes persistentes para Grafana, Prometheus y Tempo (sobreviven reinicios y reprogramación de pods)."
  type = object({
    enabled         = optional(bool, false)
    storage_class   = optional(string, "")
    grafana_size    = optional(string, "5Gi")
    prometheus_size = optional(string, "20Gi")
    tempo_size      = optional(string, "10Gi")
  })
  default = {}
}

variable "retention" {
  description = "Retención de métricas y trazas en el entorno local."
  type        = string
  default     = "24h"
}
