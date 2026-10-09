variable "namespace" {
  description = "Namespace de la vertical. Toda carga Java creada en él recibe el agente OpenTelemetry."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]{0,61}[a-z0-9])?$", var.namespace))
    error_message = "namespace debe ser un nombre DNS-1123."
  }
}

variable "team" {
  description = "Equipo dueño de la vertical. Etiqueta de routing de alertas y atributo team.tribe en la telemetría."
  type        = string
}

variable "migration_wave" {
  description = "Fase u ola del plan de migración (F0–F3), p. ej. F1-piloto o F2-ola-3."
  type        = string

  validation {
    condition     = can(regex("^F[0-3](-[a-z0-9-]+)?$", var.migration_wave))
    error_message = "migration_wave debe tener el formato F<0-3>[-sufijo], p. ej. F1-piloto."
  }
}

variable "otlp_endpoint" {
  description = "Endpoint OTLP/HTTP del agente de nodo (output app_otlp_http_endpoint de la capa 10)."
  type        = string
  default     = "http://otel-node-agent.observability.svc.cluster.local:4318"
}

variable "business_headers" {
  description = "Cabeceras de respuesta del contrato de semántica de negocio que captura el agente."
  type        = list(string)
  default     = ["X-Business-Operation", "X-Business-Outcome", "X-Business-Reason"]
}

variable "agent_extensions" {
  description = "Extensiones corporativas del agente Java (imagen con el jar y directorio dentro de la imagen)."
  type = list(object({
    image = string
    dir   = string
  }))
  default = []
}

variable "workloads" {
  description = "Cargas de la vertical. Opcional: las verticales con CD propio omiten este bloque y solo heredan la instrumentación del namespace."
  type = map(object({
    image       = string
    port        = optional(number, 8080)
    replicas    = optional(number, 1)
    env         = optional(map(string), {})
    health_path = optional(string, "/actuator/health/readiness")
    memory      = optional(string, "768Mi")
    # Dimensionamiento del JVM según el contenedor. JDK_JAVA_OPTIONS no interfiere con
    # JAVA_TOOL_OPTIONS, que gestiona el Operator para inyectar el agente.
    jvm_options = optional(string, "-XX:ActiveProcessorCount=2 -XX:MaxRAMPercentage=75")
  }))
  default = {}

  validation {
    condition     = alltrue([for w in values(var.workloads) : !contains(keys(w.env), "JAVA_TOOL_OPTIONS")])
    error_message = "JAVA_TOOL_OPTIONS lo gestiona el Operator para inyectar el agente; no debe definirse en workloads."
  }
}
