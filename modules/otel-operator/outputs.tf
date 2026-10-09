output "operator_namespace" {
  description = "Namespace del OpenTelemetry Operator."
  value       = helm_release.operator.namespace
}

output "operator_version" {
  description = "Versión de la aplicación del Operator desplegada."
  value       = helm_release.operator.metadata.app_version
}

output "java_agent_image" {
  description = "Imagen del agente Java que el Operator inyecta."
  value       = "${var.java_agent_image.repository}:${var.java_agent_image.tag}"
}
