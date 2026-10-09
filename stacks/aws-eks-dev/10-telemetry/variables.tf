variable "aws_account_id" {
  description = "Cuenta AWS de destino. El provider rechaza cualquier otra cuenta."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "aws_account_id debe tener 12 dígitos."
  }
}

variable "region" {
  description = "Región AWS del clúster EKS."
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Nombre del clúster EKS (gestionado por otro stack)."
  type        = string
}

variable "namespace" {
  description = "Namespace de la capa de telemetría."
  type        = string
  default     = "observability"
}

variable "gateway_replicas" {
  description = "Réplicas del Gateway (una por zona de disponibilidad como mínimo)."
  type        = number
  default     = 3
}

variable "secrets" {
  description = "IDs de secretos en AWS Secrets Manager. Ningún secreto reside en archivos versionados."
  type = object({
    pii_hash_salt          = string
    dynatrace_ingest_token = string
  })
}

variable "dynatrace_otlp_endpoint" {
  description = "Endpoint OTLP del ambiente Dynatrace (https://<env-id>.live.dynatrace.com/api/v2/otlp)."
  type        = string
}

variable "legacy_apm_enabled" {
  description = "Dual-Shipping hacia Dynatrace. false = cutover (F3)."
  type        = bool
  default     = true
}

variable "otel_backend_endpoint" {
  description = "Endpoint OTLP/gRPC (host:puerto, TLS) del backend OTel: Elastic APM, Grafana Tempo u otro."
  type        = string
}

variable "amp_workspace_id" {
  description = "Workspace de Amazon Managed Prometheus de la plataforma (gestionado por otro stack)."
  type        = string
}

variable "team_alert_topics" {
  description = "Tópico SNS de la guardia de cada equipo. Clave = etiqueta team de las alertas SLO."
  type        = map(string)

  validation {
    condition     = alltrue([for arn in values(var.team_alert_topics) : can(regex("^arn:aws:sns:", arn))])
    error_message = "Cada valor de team_alert_topics debe ser un ARN de SNS."
  }
}

variable "platform_alert_topic" {
  description = "Tópico SNS de Plataforma de Confiabilidad: alertas sin equipo dueño o de la infraestructura de telemetría."
  type        = string
}
