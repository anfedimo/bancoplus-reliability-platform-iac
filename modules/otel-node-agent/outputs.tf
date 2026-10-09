output "otlp_grpc_endpoint" {
  description = "Endpoint OTLP/gRPC para aplicaciones (agente del nodo local)."
  value       = "http://${var.name}.${var.namespace}.svc.cluster.local:4317"
}

output "otlp_http_endpoint" {
  description = "Endpoint OTLP/HTTP para aplicaciones (agente del nodo local). Default del agente Java 2.x."
  value       = "http://${var.name}.${var.namespace}.svc.cluster.local:4318"
}

output "rendered_config" {
  description = "Configuración renderizada del agente."
  value       = local.config
}
