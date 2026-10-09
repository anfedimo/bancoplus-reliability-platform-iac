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

variable "retention" {
  description = "Retención de métricas y trazas en el entorno local."
  type        = string
  default     = "24h"
}
