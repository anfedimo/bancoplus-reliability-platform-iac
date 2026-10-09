variable "name" {
  description = "Nombre del release y del Service del Gateway."
  type        = string
  default     = "otel-gateway"

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]{0,40}[a-z0-9])?$", var.name))
    error_message = "name debe ser un nombre DNS-1123 de máximo 42 caracteres."
  }
}

variable "namespace" {
  description = "Namespace del Gateway."
  type        = string
  default     = "observability"
}

variable "create_namespace" {
  description = "Crea el namespace. false cuando lo gestiona otro stack."
  type        = bool
  default     = true
}

variable "chart_version" {
  description = "Versión del chart open-telemetry/opentelemetry-collector."
  type        = string
  default     = "0.175.1"
}

variable "collector_image_tag" {
  description = "Tag de otel/opentelemetry-collector-contrib. Cambios de versión vía PR con validación del config."
  type        = string
  default     = "0.162.0"
}

variable "replicas" {
  description = "Réplicas del Gateway. ≥ 2 en entornos productivos."
  type        = number
  default     = 2

  validation {
    condition     = var.replicas >= 1 && var.replicas <= 20
    error_message = "replicas debe estar entre 1 y 20."
  }
}

variable "resources" {
  description = "Requests y límite de memoria por réplica. memory_limiter y GOMEMLIMIT se calculan sobre memory_limit."
  type = object({
    cpu_request    = optional(string, "200m")
    memory_request = optional(string, "512Mi")
    memory_limit   = optional(string, "1Gi")
  })
  default = {}
}

variable "pii_hash_salt" {
  description = "Sal del hash de identificadores (SHA-256). Proviene del gestor de secretos; nunca de un .tfvars versionado."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.pii_hash_salt) >= 16
    error_message = "pii_hash_salt debe tener al menos 16 caracteres."
  }
}

variable "legacy_apm" {
  description = "Dual-Shipping hacia el APM legado (Dynatrace, ingesta OTLP/HTTP). enabled = false ejecuta el cutover (F3)."
  type = object({
    enabled  = bool
    endpoint = optional(string, "")
  })
  default = { enabled = false }

  validation {
    condition     = !var.legacy_apm.enabled || can(regex("^https?://", var.legacy_apm.endpoint))
    error_message = "legacy_apm.endpoint es obligatorio (http/https) cuando legacy_apm.enabled = true."
  }
}

variable "legacy_apm_api_token" {
  description = "Token de ingesta del APM legado (scope openTelemetryTrace.ingest)."
  type        = string
  default     = ""
  sensitive   = true
}

variable "otel_backend_endpoint" {
  description = "Endpoint OTLP/gRPC (host:puerto) del backend OTel: Elastic, Tempo u otro."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9.-]+:[0-9]+$", var.otel_backend_endpoint))
    error_message = "otel_backend_endpoint debe tener el formato host:puerto."
  }
}

variable "otel_backend_insecure" {
  description = "Deshabilita TLS hacia el backend. Solo para entornos locales."
  type        = bool
  default     = false
}

variable "sampling" {
  description = "Política de tail sampling: línea base de tráfico exitoso, umbral de latencia del SLO y monto de alto valor (COP)."
  type = object({
    baseline_percentage  = optional(number, 5)
    latency_threshold_ms = optional(number, 800)
    high_value_amount    = optional(number, 50000000)
  })
  default = {}

  validation {
    condition     = var.sampling.baseline_percentage > 0 && var.sampling.baseline_percentage <= 100
    error_message = "sampling.baseline_percentage debe estar en (0, 100]."
  }

  validation {
    condition     = var.sampling.latency_threshold_ms > 0
    error_message = "sampling.latency_threshold_ms debe ser mayor que 0."
  }
}

variable "business_semantics_enabled" {
  description = "Normaliza X-Business-* a business.* y corrige el estado del span (falsos 5xx, errores ocultos en 2xx)."
  type        = bool
  default     = true
}

variable "probe_routes_regex" {
  description = "Rutas de health checks que se descartan antes de las métricas RED y del muestreo (regex RE2 sobre http.route)."
  type        = string
  default     = "^/(actuator/health|healthz|readyz|livez|health)"

  validation {
    condition     = can(regex(var.probe_routes_regex, "/actuator/health/readiness"))
    error_message = "probe_routes_regex debe ser una regex válida."
  }
}

variable "service_monitor_enabled" {
  description = "Crea un ServiceMonitor (requiere CRDs de Prometheus Operator). Scrape por pod: con N réplicas, un scrape al Service perdería métricas."
  type        = bool
  default     = false
}

variable "span_metrics_dimensions" {
  description = "Dimensiones de las métricas RED. Cada dimensión multiplica la cardinalidad: cambios vía PR."
  type        = list(string)
  default     = ["service.version", "business.outcome", "http.response.status_code", "payment.channel"]

  validation {
    condition     = length(var.span_metrics_dimensions) <= 8
    error_message = "Máximo 8 dimensiones para contener la cardinalidad."
  }
}
